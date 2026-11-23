# 装甲外观与替换

当前目标只包含四块装甲，不显示车体，也没有隐藏的车体碰撞。装甲外观与运动、命中判定分别配置。内置车辆已使用官网 AM02/AM12 STEP 派生网格，来源、尺寸、转换和光学边界见 [官方装甲 CAD](armor_cad.md)。

## 选择自定义装甲

点击“选择装甲 GLB/glTF”，选择后立即生效；“恢复内置外观”恢复官方 CAD 与兵种贴纸。外部文件保持原位置，保存配置记录其路径，迁移机器时需一起携带。glTF 依赖的纹理和 bin 文件需与模型一起保存，推荐单文件 `.glb`。

```ini
[appearance]
robot="hero_2026"
team="red"
armor_model="/absolute/path/to/armor.glb"
armor_scale=1.0
```

车辆 `robot` 支持 `infantry_3_2026/infantry_4_2026/infantry_5_2026/hero_2026/sentry_2026`。未明确写入的模块尺寸、受击宽高、半径和灯条间距继承该车型预设；明确配置的尺寸保持原值。界面切换兵种会更新预设尺寸和血量，并保留本轮统计。

- **自定义装甲局部轴**：x 为正面视角的右方，y 向上，+z 是外法向。自动居中，按网格 x 宽归一化至 `target.module_width`，再乘 armor_scale。没有独立的模型安装偏移调节。
- 节点名包含 `Team` 或 `Lightbar`（忽略大小写）时，会被替换为当前阵营材质，并在血量归零后灭灯。其他表面保留模型材质。自定义装甲自行提供图案，内置装甲使用下列现成 PNG。
- 内置 CAD 的 `module_width/module_height` 是相对标称小装甲 140×125 mm、大装甲 235×127 mm 的缩放输入。包含固定件的包围盒略大，不按该包围盒缩放至标称尺寸；默认保持 1:1。
- `lightbar_spacing/lightbar_length` 仅配置理想观测名义关键点与贴纸尺寸，不改变 CAD 导光罩；`armor_width/armor_height/armor_tilt` 配置矩形命中近似。替换模型后应核对灯条、理想关键点及受击区域。
- 装甲沿前后左右对称安装，方向间隔 90°；对向中心距仍为 `2*target.radius`，界面的伸展滑条则显示包含板体、灯条、厚度和倾角的旋转外廓直径：默认 550 mm、项目上限 600 mm。半径会根据几何尺寸换算；相邻装甲保持间隙并处于彼此正面平面后方。高度滑条直接编辑基准下沿，默认 200 mm、高度差 -100 mm；换兵种保持下沿高度。见 README。
- 不执行模型附带的控制脚本，也不自动把自定义网格变成碰撞体。

## 保留的历史车体资源

`assets/models/{infantry,hero,sentry}.glb` 是先前下载的参考车体，当前不加载。它们来自 [rm-controls/rm_description](https://github.com/rm-controls/rm_description) 固定提交 `a4b31828bf964e491d3ba5a731d12c1213562feb`，作者 Qiayuan Liao / DynamicX，许可证 BSD-3-Clause。完整许可证和来源哈希保存在 `assets/third_party/rm_description/`，下载转换工具为 `tools/fetch_reference_models.py`。旧配置中的 `body_model/body_scale` 仍可读取，但不参与显示和碰撞。

## 装甲图案贴图

步兵 3/4/5、英雄 1、哨兵均使用 [LabelMaster 的实际参考图](https://github.com/tff345/label-robomaster/tree/b517820cc8591c056098b3ac808338b084b6eabd/pic)，固定提交 `b517820cc8591c056098b3ac808338b084b6eabd`，保留 MIT 许可证于 `assets/third_party/label_robomaster/LICENSE`。程序不使用字体或绘图代码生成编号。

| 本地 PNG | 上游文件 | 用途 |
|---|---|---|
| `infantry_3.png` | `pic/3.png` | 步兵 3 |
| `infantry_4.png` | `pic/4.png` | 步兵 4 |
| `infantry_5.png` | `pic/5.png` | 步兵 5 |
| `hero.png` | `pic/B1.png` | 英雄 1 |
| `sentry.png` | `pic/sb.png` | 哨兵炮塔标识 |

哨兵的预设编号仍为 7，内置装甲正面显示炮塔轮廓。图案保存在 `assets/stickers/sentry.png`，来自 [LabelMaster 的哨兵贴纸参考图](https://github.com/tff345/label-robomaster/blob/main/pic/sb.png)，并与 [官方 2026 制作规范 V1.2.0 第 104 页附录图 5](https://bbs-web-static.robomaster.com/a36873dca86c4883b9b067eda72ad43b1767087376172/RoboMaster%202026%20%E6%9C%BA%E7%94%B2%E5%A4%A7%E5%B8%88%E9%AB%98%E6%A0%A1%E7%B3%BB%E5%88%97%E8%B5%9B%E6%9C%BA%E5%99%A8%E4%BA%BA%E5%88%B6%E4%BD%9C%E8%A7%84%E8%8C%83%E6%89%8B%E5%86%8CV1.2.0%EF%BC%8820251230%EF%BC%89.pdf#page=104) 核对。

PNG 保留完整原图，渲染时裁取中央图案、把黑底转为透明，仅将白色印刷叠加到 CAD 正面；不以旧矩形黑底覆盖零件凹凸。可在 `scripts/presets.gd` 各预设中替换 `sticker` 路径和 `sticker_region`。红蓝切换只改变灯色，白色图案保持一致。自定义 GLB/glTF 自行提供图案。原图 SHA256 与裁剪区域见 `assets/stickers/sources.json`。

## 能量机关

2025/2027 大小符预设与车辆同在目标选择框，名称带年份；符使用共享的 `scripts/rune_view.gd` 参数化几何与 `assets/rune/center_r.svg`，规则分别从年份元数据选择，不复制整套模型。符不加载自定义装甲 GLB。尺寸、灯效、安装和精度边界见 [能量机关说明](power_rune.md)。

现有 PNG/GLB 原始文件名和来源哈希保持原样，年份由引用它们的预设明确标注；后续不同年份的新装甲使用其对应资源，不覆盖 2026 贴图。

## 2026前哨站

`outpost_2026`使用独立的三块分层装甲、官方前哨站标识和有实体遮挡的塔身/底座；不加载车辆的可替换装甲模型，不修改车辆材质或几何。固定尺寸、比例复原量、素材来源和物理边界见[outpost.md](outpost.md)与[素材清单](../assets/outpost/sources.json)。
