import json
import sys
import os

def deep_merge(base, mixin):
    """
    深度合并字典，并对列表进行基于 'name' 字段的去重追加合并。
    """
    if isinstance(base, dict) and isinstance(mixin, dict):
        for k, v in mixin.items():
            if k in base:
                base[k] = deep_merge(base[k], v)
            else:
                base[k] = v
    elif isinstance(base, list) and isinstance(mixin, list):
        # 如果是列表，尝试根据 'name' 字段合并
        base_map = {}
        for i, item in enumerate(base):
            if isinstance(item, dict) and 'name' in item:
                base_map[item['name']] = i
        
        for item in mixin:
            if isinstance(item, dict) and 'name' in item and item['name'] in base_map:
                # 如果名字相同，覆盖旧的项
                index = base_map[item['name']]
                base[index] = deep_merge(base[index], item)
            else:
                # 否则追加到列表末尾
                base.append(item)
    else:
        return mixin
    return base

def load_json_safe(path):
    """安全读取 JSON 文件，失败返回空字典"""
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        return {}
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError:
        # 如果解析失败（可能是空文件或格式错误），返回空字典
        return {}
    except Exception as e:
        sys.stderr.write(f"[WARN] Failed to load {path}: {e}\n")
        return {}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        # 如果参数不够，打印空 JSON 并退出，保证管道不报错
        print("{}")
        sys.exit(0)
    
    base_data = load_json_safe(sys.argv[1])
    mixin_data = load_json_safe(sys.argv[2])
    
    # 如果两个都是空的，输出空对象
    if not base_data and not mixin_data:
        print("{}")
    elif not mixin_data:
        print(json.dumps(base_data, ensure_ascii=False, indent=2))
    elif not base_data:
        print(json.dumps(mixin_data, ensure_ascii=False, indent=2))
    else:
        result = deep_merge(base_data, mixin_data)
        print(json.dumps(result, ensure_ascii=False, indent=2))
