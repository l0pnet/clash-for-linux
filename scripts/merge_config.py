import json
import sys

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
        # 创建一个 base 列表的索引图
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
        # 非字典或列表，直接覆盖
        return mixin
    return base

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(1)
    
    with open(sys.argv[1], 'r') as f:
        base_data = json.load(f)
    
    with open(sys.argv[2], 'r') as f:
        mixin_data = json.load(f)
    
    result = deep_merge(base_data, mixin_data)
    print(json.dumps(result, ensure_ascii=False, indent=2))
