# 官方装甲 CAD

内置车辆的小装甲使用 RoboMaster 官网 AM02，大装甲使用 AM12；英雄默认大装甲，其余车辆默认小装甲。源文件是官网提供的 2020 版硬件 STEP，并非新发布的“2026 CAD”。几何与 2026 制作规范的装甲尺寸核对；前哨站、能量机关和自定义 GLB 不受此次替换影响。

## 来源与坐标

- [AM02 官方页面](https://www.robomaster.com/zh-CN/products/components/detail/2600)
- [AM12 官方页面](https://www.robomaster.com/zh-CN/products/components/detail/2599)
- 原始下载链接、STEP/GLB SHA256、逐零件包围盒和三角形数量保存在 [geometry.json](../assets/armor_cad/geometry.json)。官方资源版权归原权利人，不因转换而适用本仓库代码许可证。

导出保持毫米到米的准确换算，不按总包围盒重新归一化。局部 x 向右、y 向上、+z 向外；原点位于正面板中心、正面表面。AM12 源文件的 60° 放置旋转在转换时消除，零件间相对位置保持不变。

| 模型 | 标称尺寸 | STEP 正面板尺寸 | 含固定件的总包围盒 | 法向总厚度 |
|---|---|---|---|---|
| AM02 | 140 × 125 mm | 135 × 125 mm | 141 × 129.965 mm | 19 mm |
| AM12 | 235 × 127 mm | 230 × 127.2 mm | 236 × 130.457 mm | 19 mm |

总包围盒包含固定件，不能强行缩成标称宽高。默认配置按原尺寸显示；`module_width/module_height` 按对应标称尺寸缩放 x/y，不缩放厚度，手动改动后不再是官方原尺寸。自定义尺寸选择宽度最接近的标称模块。逐零件包围盒用于保守计算安装半径和旋转外廓，默认外廓仍为 550 mm。

`lightbar_spacing/lightbar_length` 只定义理想观测的名义关键点及贴纸尺寸，不移动或拉伸 CAD 导光罩。真实像素来自 CAD 渲染，名义关键点不保证与导光罩像素端点重合。矩形受击区仍是原有可调近似（默认 135 × 125 / 230 × 127 mm），没有改成逐三角形物理碰撞。

## 发光与相机

可见世界使用 CAD 导光罩；独立遮罩视口使用相同几何、姿态、相机和遮挡件，只保留当前点亮导光罩的可见部分。相机着色器在该遮罩附近叠加阵营色亮芯和局部光晕，再应用已有曝光。命中闪灭、超时恢复、死亡均同时控制实体材质和遮罩。预览与共享内存使用同一处理后图像；原始 3D 世界不叠加该相机光学效果。不会对全图模糊。

STEP 不包含实物 LED 的有效发光范围、辐射强度或镜头光学参数。当前假设裸露导光罩均匀发光；着色器的亮度与光晕半径是仿真取值，尚未实物标定。更换机械几何不代表已经解决识别、姿态估计或命中率问题。默认曝光没有因此提高，自瞄算法未修改。

## 再生成

程序运行直接使用仓库内 GLB 和 JSON，不需要 STEP、Python CAD 库或网络下载。只在重新导出时安装独立工具依赖：

```bash
python3 -m venv /tmp/rm-cad-export
/tmp/rm-cad-export/bin/pip install -r tools/cad-requirements.txt
/tmp/rm-cad-export/bin/python tools/convert_official_armor.py \
  --source-dir /path/to/official-step --output-dir assets/armor_cad
```

输入目录包含 `AM02.STEP` 和 `AM12.STEP`，应先核对已有清单中的源文件哈希。网格线性偏差 0.12 mm、角度偏差 0.20 rad；转换不改变机械尺寸。编号图案继续使用已有来源贴纸，只叠加白色印刷部分，不以不透明矩形覆盖 CAD 凹凸。

## 验证

```bash
./run.sh --headless --script res://tests/cad_geometry_tests.gd
./run.sh --headless --script res://tests/run_tests.gd
python3 tests/integration.py --godot "$PWD/.tools/godot"
./run.sh --script res://tests/ui_smoke.gd -- --no-ipc --camera-only
```

分别验证网格尺寸与外廓、原有仿真业务、IPC 和真实渲染的红蓝灭灯/恢复。图形测试需要可用的显示环境；纯 headless 不能代替像素验收。
