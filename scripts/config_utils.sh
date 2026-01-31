#!/bin/bash

trim_value() {
	local value="$1"
	echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

apply_tun_config() {
	local config_path="$1"
	local enable="${CLASH_TUN_ENABLE:-false}"
	if [ "$enable" != "true" ]; then
		return 0
	fi

	local stack="${CLASH_TUN_STACK:-system}"
	local auto_route="${CLASH_TUN_AUTO_ROUTE:-true}"
	local auto_redirect="${CLASH_TUN_AUTO_REDIRECT:-false}"
	local strict_route="${CLASH_TUN_STRICT_ROUTE:-false}"
	local device="${CLASH_TUN_DEVICE:-}"
	local mtu="${CLASH_TUN_MTU:-}"
	local dns_hijack="${CLASH_TUN_DNS_HIJACK:-}"

	{
		echo ""
		echo "tun:"
		echo "  enable: true"
		echo "  stack: ${stack}"
		echo "  auto-route: ${auto_route}"
		echo "  auto-redirect: ${auto_redirect}"
		echo "  strict-route: ${strict_route}"
		if [ -n "$device" ]; then
			echo "  device: ${device}"
		fi
		if [ -n "$mtu" ]; then
			echo "  mtu: ${mtu}"
		fi
		if [ -n "$dns_hijack" ]; then
			echo "  dns-hijack:"
			IFS=',' read -r -a hijacks <<< "$dns_hijack"
			for item in "${hijacks[@]}"; do
				local trimmed
				trimmed=$(trim_value "$item")
				if [ -n "$trimmed" ]; then
					echo "    - ${trimmed}"
				fi
			done
		fi
	} >> "$config_path"
}

apply_mixin_config() {
	local config_path="$1"
	local base_dir="${2:-$Server_Dir}"
	
	# 参数校验：防止空路径导致生成 .base.json 等异常文件
	if [ -z "$config_path" ]; then
		echo "[ERROR] apply_mixin_config called with empty config_path!" >&2
		return 1
	fi
	
	echo "[DEBUG] Applying mixins to: $config_path"

	local mixin_dir="${CLASH_MIXIN_DIR:-$base_dir/conf/mixin.d}"
	echo "[DEBUG] Searching mixins in: $mixin_dir"
	echo "[DEBUG] Files in $mixin_dir: $(ls "$mixin_dir" 2>/dev/null | tr '\n' ' ')"

	local mixin_paths=()

	if [ -n "${CLASH_MIXIN_PATHS:-}" ]; then

		IFS=',' read -r -a mixin_paths <<< "$CLASH_MIXIN_PATHS"

	fi



	if [ -d "$mixin_dir" ]; then

		while IFS= read -r -d '' file; do

			mixin_paths+=("$file")

		done < <(find "$mixin_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 | sort -z)

	fi



	# 检查是否存在 yq 和 python3

	local has_tools=false

	if command -v yq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then

		has_tools=true

	fi



	for path in "${mixin_paths[@]}"; do

		local trimmed

		trimmed=$(trim_value "$path")

		if [ -z "$trimmed" ]; then

			continue

		fi

		if [ "${trimmed:0:1}" != "/" ]; then

			trimmed="$base_dir/$trimmed"

		fi



		if [ -f "$trimmed" ]; then

			if [ "$has_tools" = "true" ]; then

				echo "[INFO] Merging mixin (Python+yq): $trimmed"

				local base_json="${config_path}.base.json"

				local mixin_json="${config_path}.mixin.json"

				local merged_json="${config_path}.merged.json"



												# 转换、合并、还原



												yq eval -o=json "$config_path" > "$base_json"



												yq eval -o=json "$trimmed" > "$mixin_json"



												



												# Debug: 打印文件状态



												echo "[DEBUG] Base JSON size: $(wc -c <"$base_json" 2>/dev/null || echo 0)"



												echo "[DEBUG] Mixin JSON size: $(wc -c <"$mixin_json" 2>/dev/null || echo 0)"



								



												# 容错：如果 JSON 文件为空（yq 转换失败或源文件为空），写入 {}



												[ -s "$base_json" ] || echo "{}" > "$base_json"



												[ -s "$mixin_json" ] || echo "{}" > "$mixin_json"



								



												# 执行合并，捕获 stderr



												local py_err_file="${config_path}.py.err"



												if PYTHONIOENCODING=utf-8 python3 "$base_dir/scripts/merge_config.py" "$base_json" "$mixin_json" > "$merged_json" 2>"$py_err_file"; then



													echo "[DEBUG] Merged JSON size: $(wc -c <"$merged_json" 2>/dev/null || echo 0)"



													



													if [ -s "$merged_json" ]; then



														yq eval -P "$merged_json" > "$config_path"



														echo "[DEBUG] Final YAML written to $config_path"



													else



														echo "[ERROR] Merged JSON is empty! Python script output nothing." >&2



														cat "$py_err_file" >&2



													fi



													



													# Debug: 暂时保留文件



													# rm -f "$base_json" "$mixin_json" "$merged_json" "$py_err_file"



												else



													echo "[WARN] Python merge failed for $trimmed, falling back to append" >&2



													cat "$py_err_file" >&2



													rm -f "$base_json" "$mixin_json" "$merged_json" "$py_err_file"



													{



														echo ""



														echo "# ---- mixin (fallback): ${trimmed} ----"



														cat "$trimmed"



													} >> "$config_path"



												fi

			else

				# 无高级工具，回退到简单追加

				{

					echo ""

					echo "# ---- mixin: ${trimmed} ----"

					cat "$trimmed"

				} >> "$config_path"

			fi

		else

			echo "[WARN] Mixin file not found: $trimmed" >&2

		fi

	done

}
