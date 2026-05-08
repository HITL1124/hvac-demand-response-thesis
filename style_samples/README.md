# 学位论文风格样本

## 1. 文件定位

本目录用于保存作者筛选的优秀硕博论文样本，主要用于学习学位论文的章节结构、标题层级、摘要写法、绪论组织、文献综述逻辑、模型/仿真/结果分析章节写法、结论表达和中文学术语言风格。

需要明确：

- 本目录不是论文正文；
- 本目录不是研究内容来源；
- 不得直接摘抄、改写、复用样本论文中的研究内容、数据、图表、案例对象、结论和原创观点；
- 样本只用于形式层面的写作参考；
- 从样本中提炼出的长期规则应沉淀到 `notes/style_guide.md`。

## 2. 样本文件清单

| 文件名 | 原论文题目 | 作者 | 类型/方向 | 主要参考价值 |
| --- | --- | --- | --- | --- |
| `quadrotor_control_system_jiang_2014.pdf` | 一种四旋翼无人机控制系统的设计与实现研究 | 姜成平 | 控制系统/工程实现 | 章节结构、摘要组织、绪论展开方式 |
| `high_power_high_speed_pmsm_xu_2024.pdf` | 大功率高速永磁同步电机的设计与分析 | 徐敏鹏 | 电机设计/分析 | 建模章节写法、结果分析语言、本章小结 |
| `grid_forming_energy_storage_frequency_support_zheng_2025.pdf` | 构网型储能改善新型电力系统动态频率支撑能力研究 | 郑凯泽 | 电力系统/储能 | 绪论组织、研究现状分类综述、结论写法 |
| `controllable_commutation_freewheeling_bldcm_wei_2016.pdf` | 换相续流可控的无刷直流电机驱动控制策略 | 魏延羽 | 电机控制 | 章节组织、模型与控制章节写法、结果分析表述 |
| `cnn_bearing_fault_diagnosis_zhang_2017.pdf` | 基于卷积神经网络的轴承故障诊断算法研究 | 张伟 | 算法/故障诊断 | 摘要组织、文献综述逻辑、方法章节布局 |
| `data_model_driven_converter_admittance_identification.pdf` | 基于数据-模型驱动的并网换流器多工况导纳小样本辨识方法 | 文件名未标注 | 电力电子/辨识 | 绪论结构、方法章节组织、结果章节层次 |
| `predictive_pmsm_fast_response_servo_control_li_2024.pdf` | 基于预测原理的永磁同步电机快响应伺服控制 | 李绍斌 | 伺服控制 | 建模/控制章节写法、结果分析语言、结论表达 |
| `renewable_uncertainty_power_system_risk_assessment_zhang_2025.pdf` | 考虑新能源不确定性的电力系统实时运行风险评估 | 张庭祥 | 电力系统/风险评估 | 文献综述分类、问题定义写法、结论组织 |
| `renewable_station_storage_market_li_2025.pdf` | 新能源场站配储规划与源储协同参与电力市场研究 | 李牧远 | 电力市场/储能规划 | 绪论展开方式、章节结构、总结与展望写法 |
| `dab_single_stage_dc_ac_pv_microinverter_control_strategy.pdf` | 基于DAB型单级DC-AC变换器的光伏并网微型逆变器控制策略研究 | 谢佳彧 | 电力电子/并网控制 | 绪论组织、控制策略章节写法、结果分析衔接 |
| `multi_condition_pmsm_electrical_parameter_identification.pdf` | 多工况下永磁同步电机电气参数辨识方法研究 | 王奇维 | 电机控制/参数辨识 | 建模与辨识章节结构、图表分析语言、本章小结 |
| `intelligent_vehicle_local_trajectory_planning_tracking_control.pdf` | 智能车辆局部轨迹规划与跟踪控制算法研究 | 何慧玲 | 智能控制/轨迹规划 | 章节层级、方法章节展开、仿真结果组织 |
| `pmsm_high_frequency_signal_injection_sensorless_low_speed_control.pdf` | 永磁同步电机高频信号注入无传感器低速运行自适应控制策略 | 毕广东 | 电机控制/无传感控制 | 模型说明、方法与验证衔接、结果分析表达 |
| `vpp_multi_timescale_optimal_dispatch_with_power_energy_balance.pdf` | 考虑电力电量平衡的虚拟电厂多时间尺度优化调度策略研究 | 文件名未标注 | 电力系统/虚拟电厂 | 绪论层次、问题定义、结果分析过渡 |
| `high_precision_servo_system_for_mechatronic_joints.pdf` | 面向机电一体化关节的高精度伺服系统关键技术研究 | 孙春旺 | 机电一体化/伺服系统 | 章节结构、方法展开方式、结论表达 |
| `presubmission_thesis_sample_23s130524.pdf` | 预审样本（源文件名可追溯） | 不单独整理 | 学位论文预审样本 | 形式层面的写作参考 |
| `presubmission_thesis_sample_23s130526.pdf` | 预审样本（源文件名可追溯） | 不单独整理 | 学位论文预审样本 | 形式层面的写作参考 |

## 3. 使用边界

- Web GPT 可读取这些样本，用于总结写作形式和语言风格；
- Codex 不应基于这些样本生成技术内容；
- 正式论文写作优先级仍然是：学校要求 > 导师要求 > 本项目实际研究内容 > `notes/style_guide.md` > 样本论文一般写法；
- 样本不能替代 `project_scope`、`paper_to_thesis_mapping`、`figure_registry`。

## 4. 后续维护

- 如果后续继续添加样本，应同步更新本 README；
- 如果某个样本不再使用，可以移动到 `archive/`，不要随意删除；
- 不需要在每轮写作中反复读取全部样本，通常应优先使用 `notes/style_guide.md`。
