# 第三方资源与许可

本项目原创代码、文档和程序生成的几何采用根目录的 [MIT License](LICENSE)。以下第三方资源不因根目录协议而重新授权，复制、修改或分发它们时须保留对应版权与许可声明。

| 资源 | 本仓库位置 | 上游 / 固定版本 | 许可证 |
|---|---|---|---|
| 装甲数字与哨兵图案 | `assets/stickers/*.png` | [tff345/label-robomaster](https://github.com/tff345/label-robomaster)，`b517820cc8591c056098b3ac808338b084b6eabd` | [MIT，Copyright (c) 2021 xinyang](assets/third_party/label_robomaster/LICENSE) |
| 2026前哨站标识描摹 | `assets/outpost/mark.svg` | [2026官方规则V2.2.0](https://bbs.robomaster.com/wiki/20204847/809871?source=7)图5-17；[清单](assets/outpost/sources.json) | DJI / RoboMaster版权保留，不随项目MIT重新授权 |
| 能量机关 R 标识描摹 | `assets/rune/center_r.svg` | [2027 官方规则 V1.0.0](https://bbs-web-static.robomaster.com/451e5737ba5d4463909a3013456a4e551792055647969/RoboMaster%202027%20%E6%9C%BA%E7%94%B2%E5%A4%A7%E5%B8%88%E8%B6%85%E7%BA%A7%E5%AF%B9%E6%8A%97%E8%B5%9B%E6%AF%94%E8%B5%9B%E8%A7%84%E5%88%99%E6%89%8B%E5%86%8CV1.0.0%EF%BC%8820261015%EF%BC%89.pdf) 图 4-33；[清单](assets/rune/sources.json) | DJI / RoboMaster 版权保留，不随项目 MIT 重新授权 |
| 历史参考车体（当前不加载） | `assets/models/*.glb` | [rm-controls/rm_description](https://github.com/rm-controls/rm_description)，`a4b31828bf964e491d3ba5a731d12c1213562feb` | [BSD-3-Clause，Copyright (c) 2021 Qiayuan Liao](assets/third_party/rm_description/LICENSE) |

逐文件来源、转换信息与哈希见 [贴图清单](assets/stickers/sources.json)、[模型清单](assets/third_party/rm_description/sources.json) 和 [模型说明](docs/models.md)。上述资源已随源码提供，正常启动不需要重新下载。

Godot 引擎不随 Git 仓库分发，`tools/setup_godot.py` 从官方发布页下载到被忽略的 `.tools/`。Godot 自身采用 MIT，并有独立的第三方声明，见 [Godot License](https://godotengine.org/license/)；若另行分发包含引擎的可执行包，应同时满足引擎与依赖的声明要求。

示例中可选使用的 Python、NumPy、OpenCV 由使用者另行安装，不作为本仓库内嵌代码重新授权。自定义模型、检测网络权重和其他外部素材由使用者自行确认授权。

本项目不是 RoboMaster / DJI 官方产品，未获得官方背书。规则与产品文档链接用于解释参数来源；仿真近似、图案或品牌名称的使用不代表官方认证，也不授予商标权。
