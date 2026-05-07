# 数据部分——data文件夹


Dymola使用佐耀20250112-20250115四天的供回水温度、室外温度和太阳辐照度进行仿真，并导出状态空间方程的输入量input.mat和状态量state.mat

## rawdata

input.mat
	7×5761
	时间（60s间隔）
	供水温度（K，佐耀数据）
	送风流量（kg/s，仿真时固定15）
	室外温度（K，佐耀数据）
	太阳辐照度（W/m2，佐耀数据）
	内部得热（W，典型取值）
state.mat
	3×5761
	时间（60s间隔）
	墙节点温度（K，仿真得）
	室内温度（K，仿真得）
HPdata.mat
	热泵仿真数据
	4×5761
	时间（60s间隔）
	电功率（W）
	热功率（W）
	实时COP
Fandata.mat
	风机仿真数据
	3×5761
	时间（60s间隔）
	送风机功率（W）
	回风机功率（W）
Fandata_for_fit.,at
	不同供风流量下（7.5:2.5:30）风机功率数据，在FanPowerFitting.m中对总功率进行三次多项式拟合
processeddata
	由于仿真初期会存在系统启动带来的误差，经由src/processDymola直接取rawdata后三天的数据得到的处理后的数据

# 代码部分——src文件夹

## 1 processDymola.mlx

由于仿真初期会存在系统启动带来的误差，直接取后三天的数据作为验证，这一部分主要是这个作用

## 2 validate_ss_Model.m

验证使用辨识出的状态空间模型得到的状态值与仿真得到的状态值是否相合

## 3 FanPowerFitting.m

对$P_{fan} = \alpha_{1}m_{as}^{3}+\alpha_{2}m_{as}^{2}+\alpha_{3}m_{as}+\alpha_{4}$做拟合

## 4 validata_ss_Power

- **温度状态验证**：用已识别的离散状态空间模型（N4SID）在给定输入 u（processed_input.mat） 下，预测输出温度 y=[Tw,Ti]y=[T_w,T_i]y=[Tw​,Ti​]，并与 Dymola 的温度真值（processed_state.mat）对比。

- **热泵功率计算与验证**：把预测得到的室温 Ti 与输入信号一起喂给热泵机理模型，得到热泵电功率/热功率/COP，并与 Dymola 的热泵功率真值对比。

- **风机功率计算与验证**：用质量流量 m 的三次多项式拟合模型计算风机总功率（送风机+回风机），并与 Dymola 导出的风机功率真值对比。

### 模块 1：用户配置（模型与开关）

**输入：** 手动填写的参数  
**输出：** 后续所有模块用到的配置

包含：

- 状态空间模型矩阵 (A,B,C,D)（N4SID 辨识结果）
    
- 创新形式的一步预测增益 (K)
    
- 采样时间 `Ts`
    
- 是否去均值 `useRemoveMean`
    
- 绘图时间单位开关 `plotTimeInHours`
    
---

### 模块 2：读取数据（输入/输出/时间轴）

**输入：**

- `processed_state.mat`：状态/输出数据 (y\in\mathbb{R}^{N\times 2})
    
- `processed_input.mat`：输入数据 (u\in\mathbb{R}^{N\times 5})
    
**输出：**

- `y = [Tw, Ti]`（单位 K）
    
- `u = [Tsup, mdot, To, Isol, Qint]`（温度 K，流量 kg/s）
    
- `t`：时间向量（若文件无时间则按 `Ts` 生成）
    
- `tt`：用于绘图的时间轴（小时或秒）
    
- `xlab`：横坐标标签
    

主要做：

- 自动从 MAT 文件里提取最大数值矩阵作为数据（`pickLargestNumericMatrix`）
    
- 检查维度是否符合 (N\times2)、(N\times5)
    
- 统一生成 `tt`，避免后续绘图时报 “tt 未定义”
    
### 模块 3：去均值（可选，需与辨识阶段一致）

**输入：**

- 原始 `u, y`
    
- 开关 `useRemoveMean`
    
**输出：**

- 去均值后的 `uZ, yZ`
    
- 均值 `uMean, yMean`（用于后面加回去）
    

作用：

- 若辨识阶段对数据做了 detrend/remove mean，那么验证阶段也必须做同样处理；
    
- 预测完成后再把均值加回，回到原量纲。
    
### 模块 4：初始化状态 ($x_0$)

**输入：**

- 去均值后的初始输出 `yZ(1,:)`
    
- 去均值后的初始输入 `uZ(1,:)`
    
- 模型矩阵 (C,D)
    

**输出：**

- 初始状态 `x0`
    

方法：

- 根据输出方程 (y_0 = Cx_0 + Du_0) 反推
    
- 这里 (D=0)，所以用 (x_0=C^{-1}y_0)（若 (C) 不可逆则用 `pinv(C)`）
    
### 模块 5：开环仿真（Open-loop）

**输入：**

- 初始状态 `x0`
    
- 去均值输入序列 `uZ`
    
- 状态空间模型 (A,B,C,D)
    
**输出：**

- `yhat_ol`：开环预测输出（(N\times2)，对应 ([Tw,Ti])）
    
算法对应：

- 输出：$\hat y(k)=Cx(k)+Du(k)$
    
- 状态更新：$x(k+1)=Ax(k)+Bu(k)$
    
- 这里不使用测量修正（等价于 (e=0)）
    
用途：
- 模拟“日前预测”场景：未来没有测量量可用。
    

### 模块 6：一步预测/跟踪（1-step, Innovation Form）

**输入：**

- 初始状态 `x0`
    
- 去均值输入 `uZ`
    
- 去均值测量输出 `yZ`
    
- (A,B,C,D) 与创新增益 (K)
    

**输出：**

- `yhat_1s`：一步预测输出$(N\times2)$
    

算法对应：

- 预测：$\hat y(k)=Cx(k)+Du(k)$
    
- 创新：$e(k)=y(k)-\hat y(k)$
    
- 修正更新：$x(k+1)=Ax(k)+Bu(k)+Ke(k)$
    

用途：

- 模拟“有测量反馈可用”的在线跟踪（比开环通常更贴近真值）。
    

### 模块 7：热泵功率计算（机理建模）

**输入：**

- 来自输入数据：`Tsup`、`mAir`、`Tout`
    
- 来自温度预测：`Ti_ol`（开环室温）、`Ti_1s`（一步预测室温）
    
- 参数结构体 `hpPar`
    

**输出：**

- `Php_ol, COP_ol, Qcoil_ol, Tret_ol`
    
- `Php_1s, COP_1s, Qcoil_1s, Tret_1s`
    

说明：

- 机理函数 `calcHpPowerCarnotEpsNTU(...)` 内部完成：
    
    - 盘管 UA(t) → ε-NTU → 盘管热量 $Q_{\text{coil}}$
        
    - Carnot_TCon 结构 → COP → 电功率 $P_{hp}=Q_{\text{coil}}/COP$
        

#### 模块 7.1：读取热泵真值并对比

**输入：**

- `processed_HPdata.mat`：$N\times3$ 真值数据
**输出：**

- `Pele_sim`：Dymola 热泵电功率
    
- `Qcon_sim`：Dymola 热泵冷凝侧热量
    
- `COP_sim`：Dymola COP
    

额外做了一个一致性检查：

- 验证真值内部是否满足 $P \approx Q/COP$（主要用于排查列顺序/单位错误）。
    

### 模块 8：风机功率计算（拟合模型，总功率）

**输入：**

- `mAir`：空气质量流量（kg/s）
    
- `fanPar`：三次多项式拟合系数
    

**输出：**

- `Pfan_tot_fit`：风机总功率拟合值（W）
    

模型形式：

- $P_{\text{fan,tot}}(\dot m)=p_1\dot m^3+p_2\dot m^2+p_3\dot m+p_4$
    
- 这里拟合对象明确为：**送风机功率 + 回风机功率**的总和。
    
#### 模块 8.1：读取风机真值并对比

**输入：**

- `processed_Fandata.mat`：$N\times2$
    
    - 第 1 列：送风机功率
        
    - 第 2 列：回风机功率
        

**输出：**

- `Pfan_sup_sim`、`Pfan_ret_sim`
    
- `Pfan_tot_sim = Pfan_sup_sim + Pfan_ret_sim`
    

用于与拟合得到的 `Pfan_tot_fit` 对比。

### 模块 9–10：绘图对比

**输入：**

- `tt` 时间轴
    
- 热泵：机理结果与真值结果
    
- 风机：拟合结果与真值总功率
**输出：**
- 热泵电功率对比图、热功率对比图、COP 对比图
    
- 风机总功率对比图
### 模块 11–13：误差评价

**输入：**

- “模型输出”和“Dymola 真值”
    
    - 热泵：`Php` vs `Pele_sim`，`Qcoil` vs `Qcon_sim`，`COP` vs `COP_sim`
        
    - 风机：`Pfan_tot_fit` vs `Pfan_tot_sim`
        
    - 温度：`yhat_ol/yhat_1s` vs `y`
        
**输出：**
- RMSE、MAE、MaxAbs（在命令窗口打印）
### 模块 14–15：温度对比图 & 稳定性检查

**输入：**
- `y`、`yhat_ol`、`yhat_1s`
- 状态矩阵 `A`
**输出：**
- 温度对比图（Tw、Ti）
- `eig(A)` 与稳定性判断（离散系统要求 $|\lambda|<1$