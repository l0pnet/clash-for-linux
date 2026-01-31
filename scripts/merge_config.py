import json
import sys
import os

def deep_merge(base, mixin):
    """
    深度合并字典。
    列表合并策略：
    1. 字典列表（如 proxies）：按 name 去重追加到末尾。
    2. 字符串列表（如 proxy-groups.proxies）：将 mixin 的内容【插入到 base 的前面】并去重。
       这样你的私有节点会出现在列表的最顶端，一目了然。
    """
    if isinstance(base, dict) and isinstance(mixin, dict):
        for k, v in mixin.items():
            if k in base:
                base[k] = deep_merge(base[k], v)
            else:
                base[k] = v
    elif isinstance(base, list) and isinstance(mixin, list):
        if not mixin:
            return base
            
        # 策略 1：非字典列表（字符串列表，如节点名单）
        # 执行【Prepend + Unique】策略
        if len(mixin) > 0 and not isinstance(mixin[0], dict):
            # 将 mixin 插到前面，然后把 base 里重复的去掉
            new_list = list(mixin) # 复制 mixin
            existing = set(mixin)
            for item in base:
                if item not in existing:
                    new_list.append(item)
            # 修改 base 内容（原地修改）
            base[:] = new_list
            return base
            
        # 策略 2：字典列表（如 proxies, proxy-groups）
        # 执行【Upsert】策略
        base_map = {}
        for i, item in enumerate(base):
            if isinstance(item, dict) and 'name' in item:
                base_map[item['name']] = i
        
        for item in mixin:
            if isinstance(item, dict) and 'name' in item:
                name = item['name']
                if name in base_map:
                    # 名字存在：深度合并（递归）
                    idx = base_map[name]
                    base[idx] = deep_merge(base[idx], item)
                else:
                    # 名字不存在：追加到末尾
                    base.append(item)
            else:
                base.append(item)
    else:
        return mixin
    return base

def load_json_safe(path):
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        return {}
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except:
        return {}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("{}")
        sys.exit(0)
    
    base = load_json_safe(sys.argv[1])
    mixin = load_json_safe(sys.argv[2])
    
    if not base:
        print(json.dumps(mixin, ensure_ascii=False, indent=2))
    elif not mixin:
        print(json.dumps(base, ensure_ascii=False, indent=2))
    else:
        result = deep_merge(base, mixin)
        print(json.dumps(result, ensure_ascii=False, indent=2))
