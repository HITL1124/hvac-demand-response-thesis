within ;
package ASHP_guohe

  model ASHP_V3
    "RMSE:0.6214%,NMBE:-0.7129,CVRMSE:1.8499%"
    extends Modelica.Icons.Example;

    // ============================================================================
    // 1. 介质定义
    // ============================================================================

    replaceable package MediumA = Buildings.Media.Air
      "空气侧介质模型";
    replaceable package MediumW = Buildings.Media.Water
      "水侧介质模型";

    // ============================================================================
    // 2. 设计工况与房间参数
    // ============================================================================

    // ---------------- 2.1 热泵与散热器额定工况 ----------------

    parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 1735.2e3
      "热泵冷凝器（供热侧）额定热流量";
    parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 5
      "冷凝器设计供回水温差（约 5 K）";
    parameter Modelica.Units.SI.TemperatureDifference dTEVa_nominal = -5
      "蒸发器设计进出水温差（约 5 K，符号为负）";

    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
        QHea_flow_nominal/4200/dTCon_nominal
      "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 72
      "热泵水侧实际质量流量";
    parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 180
      "蒸发器空气侧额定质量流量";
    parameter Modelica.Units.SI.VolumeFlowRate VAir_flow_nominal = mAir_flow_nominal/1.2
      "蒸发器空气侧额定体积流量（按 ρ≈1.2 kg/m³）";

    parameter Modelica.Units.SI.HeatFlowRate QRad_flow_nominal = QHea_flow_nominal*0.85
      "散热器额定热流量（约 0.85×QHea_flow_nominal）";
    parameter Modelica.Units.SI.Temperature TRadSup_nominal = 273.15 + 40
      "散热器额定供水温度";
    parameter Modelica.Units.SI.Temperature TRadRet_nominal = 273.15 + 35
      "散热器额定回水温度";
    parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
      "系统供回水初始温度";
    parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 20
      "系统室内初始温度";

    // ---------------- 2.2 房间/建筑几何与空气 ----------------

    parameter Modelica.Units.SI.Area A_floor = 30000
      "建筑面积 (m²)";
    parameter Modelica.Units.SI.Height H_floor = 3
      "层高 (m)";
    parameter Modelica.Units.SI.Volume V = A_floor*H_floor
      "房间体积（长×宽×高）";
    parameter Modelica.Units.SI.MassFlowRate mA_flow_nominal = V*1.2*1.5/3600
      "房间空气额定质量流量（换气次数约 1.5 次/h）";
    parameter Modelica.Units.SI.HeatFlowRate QRooInt_flow = 4000
      "房间内部得热（人员、设备等），用于参考";

    // ---------------- 2.3 建筑等效 RC 参数（已标定） ----------------

    parameter Modelica.Units.SI.ThermalResistance RExt_set = 1.0e-5
      "外墙等综合传热热阻（设置值）";
    parameter Modelica.Units.SI.ThermalResistance RExtRem_set = 0.1e-7
      "与外界环境的剩余热阻（设置值）";
    parameter Modelica.Units.SI.HeatCapacity CExt_set = 2e9
      "外墙等热容（设置值，用于 RC 模型）";

    // ============================================================================
    // 3. 管路参数（供回水管）
    // ============================================================================

    parameter Modelica.Units.SI.Length pipeLengthSupply = 750
      "供水管长度（等效布置）";
    parameter Modelica.Units.SI.Length pipeLengthReturn = 750
      "回水管长度（等效布置）";
    parameter Modelica.Units.SI.Diameter pipeDiameter = 0.25
      "管径估算，可满足约 0.95 kg/s 流量";
    parameter Modelica.Units.SI.Thickness thicknessIns = 0.02
      "保温层厚度 (m)";
    parameter Modelica.Units.SI.ThermalConductivity lambdaIns = 0.03
      "保温材料导热系数 (W/m·K)";

    // ============================================================================
    // 4. 内部得热与热通量源
    // ============================================================================

    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow preHea
      "预设房间内部得热（对流部分）"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={102,86})));

    // MAT 文件 Q_int.mat：Q_int (1440×2) =[time[s], Q[W]]
    Modelica.Blocks.Sources.CombiTimeTable IntGainTab(
      tableOnFile=true,
      fileName="D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/Q_int.mat",
      tableName="Q_int",
      columns={2},
      smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation=Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "内部得热时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-210,88})));

    // ============================================================================
    // 5. 散热器及水侧测点
    // ============================================================================

    Buildings.Fluid.HeatExchangers.Radiators.RadiatorEN442_2 rad(
      redeclare package Medium = MediumW,
      energyDynamics  = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start         = TIni,
      fraRad          = 0.35,
      Q_flow_nominal  = QRad_flow_nominal,
      T_a_nominal     = TRadSup_nominal,
      T_b_nominal     = TRadRet_nominal,
      m_flow_nominal  = mHeaPum_flow_nominal)
      "水侧散热器（EN442-2 标准模型）"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={38,-14})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temSup(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "供水温度传感器（散热器前）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-30})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temRet(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "回水温度传感器（散热器后）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=270,
        origin={74,-30})));

    // ============================================================================
    // 6. 水侧循环水泵与供回水管
    // ============================================================================

    Buildings.Fluid.Movers.FlowControlled_m_flow pumHeaPum(
      redeclare package Medium = MediumW,
      T_start        = TIni,
      m_flow_nominal = mHeaPum_flow_nominal,
      m_flow_start   = 0.85,
      nominalValuesDefineDefaultPressureCurve = true,
      use_riseTime   = false,
      energyDynamics = Modelica.Fluid.Types.Dynamics.SteadyState)
      "散热器侧循环水泵"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-98})));

    Buildings.Fluid.FixedResistances.Pipe pipeSupply(
      redeclare package Medium = MediumW,
      length         = pipeLengthSupply,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "供水干管（带保温与热损失）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-62})));

    Buildings.Fluid.FixedResistances.Pipe pipeReturn(
      redeclare package Medium = MediumW,
      length         = pipeLengthReturn,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "回水干管（带保温与热损失）"
      annotation (Placement(transformation(
        extent={{10,-10},{-10,10}},
        rotation=90,
        origin={74,-62})));

    Modelica.Blocks.Sources.Constant WaterPumpflow(k=mHeaPum_flow_real)
      "水侧水泵质量流量设定（kg/s）" annotation (Placement(
          transformation(extent={{-10,-10},{10,10}}, origin={-134,-98})));

    // ============================================================================
    // 7. 气象边界与室外温度
    // ============================================================================

    // MAT 文件 TOut.mat：TOut (1440×2) = [time[s], TOut[°C]]
    Modelica.Blocks.Sources.CombiTimeTable TOutTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/beiquzhu/0101-0130/TOut.mat",
      tableName     = "TOut",
      columns       = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "室外温度时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-250,88})));

    Buildings.HeatTransfer.Sources.PrescribedTemperature TOut
      "室外温度边界（供管道与房间外墙使用）"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-128,46})));

    // ============================================================================
    // 8. 热泵水侧测点（冷凝器进出水）
    // ============================================================================

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPOut(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器出口水温传感器"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-42,-138})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPIn(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器入口水温传感器"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=-90,
        origin={74,-94})));

    // ============================================================================
    // 9. 房间 RC 模型与辐射/对流耦合
    // ============================================================================

    Modelica.Blocks.Sources.Constant solRadConst[2](k=0)
      "简化：两朝向窗面太阳辐射取 0"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-90,70})));

    Buildings.ThermalZones.ReducedOrder.RC.OneElement room(
      redeclare package Medium = MediumA,
      energyDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start             = 273.15 + 20,
      nOrientations       = 2,
      AExt                = {10000, 2000},
      AWin                = {600,   600},
      ATransparent        = {600,   600},
      hConWin             = 2.7,
      RWin                = 1.66e-4,
      gWin                = 0.4,
      ratioWinConRad      = 0.09,
      indoorPortWin       = false,
      indoorPortExtWalls  = false,
      hConExt             = 8.7,
      RExt                = {RExt_set},
      RExtRem             = RExtRem_set,
      CExt                = {CExt_set},
      nExt                = 1,
      VAir                = V,
      hRad                = 5.0)
      annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={10,50})));

    Modelica.Blocks.Sources.RealExpression TOut_K(y=TOutTab.y[1] + 273.15)
      "室外温度（K）供热边界和空气源使用"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-202,46})));

    // ============================================================================
    // 10. 空气源热泵蒸发器侧：空气边界与风机
    // ============================================================================

    Buildings.Fluid.Sources.Boundary_pT ambAirSource(
      redeclare package Medium = MediumA,
      use_T_in=true,
      use_p_in=false,
      nPorts=1)
      "蒸发器环境空气入口边界"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-118,-170})));

    Buildings.Fluid.Movers.FlowControlled_m_flow fan(
      redeclare package Medium = MediumA,
      m_flow_nominal=mAir_flow_nominal,
      m_flow_start=0.85,
      nominalValuesDefineDefaultPressureCurve=true,
      use_riseTime=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState)
      "蒸发器侧送风机"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=0,
        origin={-78,-170})));

    Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
      redeclare package Medium1 = MediumW,
      redeclare package Medium2 = MediumA,
      m1_flow_nominal=mHeaPum_flow_nominal,
      m2_flow_nominal=mAir_flow_nominal,
      show_T=true,
      dp1_nominal=2000,
      dp2_nominal=200,
      energyDynamics=Modelica.Fluid.Types.Dynamics.FixedInitial,
      QCon_flow_nominal=QHea_flow_nominal,
      dTEva_nominal=dTEVa_nominal,
      dTCon_nominal=dTCon_nominal,
      use_eta_Carnot_nominal=true,
      T1_start=TIni)
      "空气源热泵（Carnot 模型，给定冷凝温度）"
      annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={14,-150})));

    Buildings.Fluid.Sources.Boundary_pT ambAirSink(
      redeclare package Medium = MediumA,
      nPorts=1)
      "蒸发器环境空气出口边界"
      annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={130,-174})));

    Modelica.Blocks.Sources.Constant AirFanflow(k=mAir_flow_nominal)
      "空气侧风机质量流量设定" annotation (Placement(transformation(
            extent={{-10,-10},{10,10}}, origin={-134,-130})));

    // ============================================================================
    // 11. 热泵温度设定一阶滤波 & I/O
    // ============================================================================

    Modelica.Blocks.Sources.RealExpression IntGain(y=IntGainTab.y[1])
      "内部得热功率（W）"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={54,86})));

    Modelica.Blocks.Continuous.FirstOrder HPtau(
      k=1,
      T=360,
      y_start=TIni)
      "热泵出口温度设定一阶滤波（τ≈360 s）"
      annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={46,-122})));

    Modelica.Blocks.Interfaces.RealInput TSetInput
      "热泵出口温度设定值（K）"
      annotation (Placement(transformation(extent={{-20,-20},{20,20}}, origin={-300,-40})));

    Modelica.Blocks.Interfaces.RealOutput TRoom
      "室内温度输出（℃）"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={182,-42})));

    Modelica.Blocks.Math.UnitConversions.To_degC to_degC
      "房间空气温度 K → ℃"
      annotation (Placement(transformation(extent={{66,60},{80,74}})));

    Buildings.Fluid.Sources.Boundary_pT RetSink(
      redeclare package Medium = MediumW,
      nPorts=1)
      "水侧压力边界与热膨胀容"
      annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={134,-144})));

  equation
    // ============================================================================
    // 12. 代数关系：输出与设定
    // ============================================================================

    TRoom   = to_degC.y;
    HPtau.u = TSetInput;

    // ============================================================================
    // 13. 水侧：热泵 → 水泵 → 供水管 → 散热器 → 回水管 → 热泵
    // ============================================================================

    connect(pumHeaPum.port_b, pipeSupply.port_a)
      annotation (Line(points={{-70,-88},{-70,-72}}, color={0,127,255}));

    connect(pipeSupply.port_b, temSup.port_a)
      annotation (Line(points={{-70,-52},{-70,-40}}, color={0,127,255}));

    connect(temSup.port_b, rad.port_a) annotation (Line(
        points={{-70,-20},{-70,-14},{28,-14}},
        color={0,127,255},
        smooth=Smooth.None));

    connect(rad.port_b, temRet.port_a)
      annotation (Line(points={{48,-14},{74,-14},{74,-20}}, color={0,127,255}));

    connect(temRet.port_b, pipeReturn.port_a)
      annotation (Line(points={{74,-40},{74,-52}},                   color={0,127,255}));

    connect(pipeReturn.port_b, temHPIn.port_a)
      annotation (Line(points={{74,-72},{74,-84}}, color={0,127,255}));

    connect(WaterPumpflow.y, pumHeaPum.m_flow_in)
      annotation (Line(points={{-123,-98},{-82,-98}}, color={0,0,127}));

    connect(temHPOut.port_a, pumHeaPum.port_a) annotation (Line(
        points={{-52,-138},{-70,-138},{-70,-108}},
        color={0,127,255}));

    // ============================================================================
    // 14. 管道与房间对室外环境的热交换
    // ============================================================================

    connect(TOut.port, pipeSupply.heatPort) annotation (Line(
        points={{-118,46},{-88,46},{-88,-62},{-75,-62}},
        color={191,0,0}));

    connect(pipeReturn.heatPort, TOut.port)
      annotation (Line(points={{69,-62},{-46,-62},{-46,46},{-118,46}},
                       color={191,0,0}));

    connect(TOut.port, room.extWall) annotation (Line(
        points={{-118,46},{-14,46}},
        color={191,0,0}));

    connect(TOut.port, room.window) annotation (Line(
        points={{-118,46},{-46,46},{-46,54},{-14,54}},
        color={191,0,0}));

    // ============================================================================
    // 15. 热泵控制、房间内部得热与太阳辐射耦合
    // ============================================================================

    connect(solRadConst.y, room.solRad) annotation (Line(
        points={{-79,70},{-20,70},{-20,65},{-15,65}},
        color={0,0,127}));

    connect(rad.heatPortCon, room.intGainsConv) annotation (Line(
        points={{36,-6.8},{36,54},{34,54}},
        color={191,0,0}));

    connect(rad.heatPortRad, room.intGainsRad) annotation (Line(
        points={{40,-6.8},{40,58},{34,58}},
        color={191,0,0}));

    connect(TOut_K.y, TOut.T) annotation (Line(
        points={{-191,46},{-140,46}},
        color={0,0,127}));

    connect(preHea.port, room.intGainsConv) annotation (Line(
        points={{112,86},{118,86},{118,54},{34,54}},
        color={191,0,0}));

    connect(TOut_K.y, ambAirSource.T_in) annotation (Line(
        points={{-191,46},{-166,46},{-166,-166},{-130,-166}},
        color={0,0,127}));

    connect(IntGain.y, preHea.Q_flow)
      annotation (Line(points={{65,86},{92,86}}, color={0,0,127}));

    connect(HPtau.y, heaPum.TSet)
      annotation (Line(points={{35,-122},{26,-122},{26,-141}}, color={0,0,127}));

    connect(room.TAir, to_degC.u) annotation (Line(
        points={{35,66},{60,66},{60,67},{64.6,67}},
        color={0,0,127}));

    // ============================================================================
    // 16. 空气源侧：环境空气 → 风机 → 蒸发器 → 环境空气
    // ============================================================================

    connect(ambAirSource.ports[1], fan.port_a)
      annotation (Line(points={{-108,-170},{-88,-170}}, color={0,127,255}));

    connect(fan.port_b, heaPum.port_a2) annotation (Line(
        points={{-68,-170},{-2,-170},{-2,-156},{4,-156}},
        color={0,127,255}));

    connect(heaPum.port_b2, ambAirSink.ports[1]) annotation (Line(
        points={{24,-156},{114,-156},{114,-174},{120,-174}},
        color={0,127,255}));

    connect(AirFanflow.y, fan.m_flow_in) annotation (Line(points={{-123,-130},{-78,
            -130},{-78,-158}}, color={0,0,127}));

    // ============================================================================
    // 17. 热泵冷凝器与水力边界
    // ============================================================================

    connect(temHPOut.port_b, heaPum.port_b1) annotation (Line(
        points={{-32,-138},{-2,-138},{-2,-144},{4,-144}},
        color={0,127,255}));

    connect(temHPIn.port_b, heaPum.port_a1) annotation (Line(
        points={{74,-104},{74,-144},{24,-144}},
        color={0,127,255}));

    connect(RetSink.ports[1], heaPum.port_a1)
      annotation (Line(points={{124,-144},{24,-144}}, color={0,127,255}));

    annotation (
      Icon(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,120}})),
      Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,120}})),
      uses(Buildings(version="12.1.0"), Modelica(version="4.0.0")),
      experiment(
        StopTime=2592000,
        Interval=3600,
        __Dymola_Algorithm="Dassl"));
  end ASHP_V3;

  model Pipe_cal
    "基于DONOT_MODIFY_20250115_lunwen_withHP，测试传输延迟，620s，0.99"
    extends Modelica.Icons.Example;

    // ====== 用于测试的供水温度阶跃（只在做延迟辨识时用） ======
    parameter Modelica.Units.SI.Temperature Tstep_ini  = 313.15 "起始供水温度，40°C";
    parameter Modelica.Units.SI.Temperature Tstep_fin  = 323.15 "阶跃后温度，50°C";
    parameter Modelica.Units.SI.Time       tStep       = 3600   "阶跃发生时刻 1h";

    // ====== 63.2% 传输延迟测量 ======
    parameter Real frac632 = 1 - exp(-1);  // 0.632

    // 用阶跃设定值近似散热器入口的 初值 / 终值
    Modelica.Blocks.Sources.RealExpression Ttarget_632(
      y = Tstep_ini + frac632*(Tstep_fin - Tstep_ini))
      "散热器入口达到 63.2% 阶跃幅度时的目标温度";

    // 记录时间用的一些变量（离散量）
    discrete Real t_step(start=0, fixed=true) "阶跃发生时间";
    discrete Real t_632(start=0, fixed=true)  "散热器入口达到 63.2% 时刻";
    discrete Real tau_63(start=0, fixed=true) "用 63.2% 定义的时间常数 / 传输延迟";

    discrete Boolean gotStep(start=false, fixed=true);
    discrete Boolean got632(start=false, fixed=true);

    // ============================================================================
    // 介质定义
    // ============================================================================

    replaceable package MediumA = Buildings.Media.Air
      "空气侧介质模型";
    replaceable package MediumW = Buildings.Media.Water
      "水侧介质模型";

    // ============================================================================
    // 设计工况与房间参数
    // ============================================================================

    // ---------------------- 散热器与热泵额定工况 ----------------------

    parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 480e3
      "热泵冷凝器（供热侧）额定热流量";
    parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
      "冷凝器设计供回水温差（约 5 K）";
    parameter Modelica.Units.SI.TemperatureDifference dTEVa_nominal = -5
      "蒸发器设计进出水温差（约 5 K，符号为负）";

    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
        QHea_flow_nominal/4200/dTCon_nominal
      "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
      "热泵水侧实际质量流量";
    parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
      "蒸发器空气侧额定质量流量";
    parameter Modelica.Units.SI.VolumeFlowRate VAir_flow_nominal = mAir_flow_nominal/1.2
      "蒸发器空气侧额定体积流量（按 ρ≈1.2 kg/m³）";

    parameter Modelica.Units.SI.HeatFlowRate QRad_flow_nominal = QHea_flow_nominal*0.85
      "散热器额定热流量15881.9";
    parameter Modelica.Units.SI.Temperature TRadSup_nominal = 273.15 + 40
      "散热器额定供水温度";
    parameter Modelica.Units.SI.Temperature TRadRet_nominal = 273.15 + 38
      "散热器额定回水温度";
    parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
      "系统供回水初始温度";
    parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 20
      "系统室内初始温度";

    // ---------------------------- 房间与空气 ----------------------------

    parameter Real s = QHea_flow_nominal/18000;
    parameter Modelica.Units.SI.Area A_floor = 500 * s * 2 "建筑面积 (m²)";
    parameter Modelica.Units.SI.Height H_floor = 8 "层高 (m)";
    parameter Modelica.Units.SI.Volume V = A_floor*H_floor
      "房间体积（长×宽×高）";
    parameter Modelica.Units.SI.MassFlowRate mA_flow_nominal = V*1.2*1.5/3600
      "房间空气额定质量流量（换气次数约 1.5 次/h）";
    parameter Modelica.Units.SI.HeatFlowRate QRooInt_flow = 4000
      "房间内部得热（人员、设备等），用于参考";

    // 基于建筑物理的热阻热容计算

    // 外墙面积估算 (假设方形建筑，4面外墙)
    parameter Modelica.Units.SI.Length L_building = sqrt(A_floor) "建筑边长";
    parameter Modelica.Units.SI.Area A_wall_ext = 4 * L_building * H_floor
      "外墙总面积";

    // 典型商业建筑传热系数 (U值)
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer U_wall = 1.2
      "外墙U值 (W/m²·K) - 普通建筑标准";

    // 计算总热阻 (R = 1/(U×A))
    parameter Modelica.Units.SI.ThermalResistance R_total = 1/(U_wall * A_wall_ext)
      "建筑总热阻";

    // 热容计算 - 基于建筑质量
    parameter Modelica.Units.SI.Density rho_concrete = 2400 "混凝土密度 (kg/m³)";
    parameter Modelica.Units.SI.SpecificHeatCapacity cp_concrete = 1000
      "混凝土比热 (J/kg·K)";
    parameter Modelica.Units.SI.Thickness d_wall = 0.1 "墙体厚度 (m)";

    // 建筑热容 (考虑墙体、楼板等热质量)
    parameter Modelica.Units.SI.HeatCapacity C_total =
      A_wall_ext * d_wall * rho_concrete * cp_concrete * 0.6
      "建筑总热容 (考虑60%有效热质量)";

    // --------- 外墙等效热阻 / 热容（增加缩放因子便于校准） ---------

    parameter Real kR = 0.5
      "外墙整体热阻缩放因子 (>1: 保温更好，热损失更小)";
    parameter Real kC = 1
      "建筑热容缩放因子 (>1: 热惰性更大)";

    parameter Modelica.Units.SI.ThermalResistance RExt_set =
      kR * (3e-4*0.8*1.2*1.4*1.2*1.2 / s)
      "外墙等综合传热热阻（设置值）";

    parameter Modelica.Units.SI.ThermalResistance RExtRem_set =
      kR * (1.2e-4*0.8*1.2*1.4*1.2*1.2 / s)
      "与外界环境的剩余热阻（设置值）";

    parameter Modelica.Units.SI.HeatCapacity CExt_set =
      kC * (1e7*1.2 * s)
      "外墙等热容（设置值，用于 RC 模型）";

    // ============================================================================
    // 管路参数（供回水管）
    // ============================================================================

    parameter Modelica.Units.SI.Length pipeLengthSupply = 500
      "基于典型房间布局的供水管长度";
    parameter Modelica.Units.SI.Length pipeLengthReturn = 500
      "基于典型房间布局的回水管长度";
    parameter Modelica.Units.SI.Diameter pipeDiameter = 0.25
      "可满足约 0.95 kg/s 流量的管径估算值";
    parameter Modelica.Units.SI.Thickness thicknessIns = 0.02
      "保温层厚度 (m)";
    parameter Modelica.Units.SI.ThermalConductivity lambdaIns = 0.02
      "保温材料导热系数 (W/m.K)";

    // ============================================================================
    // 热源与内部得热
    // ============================================================================

    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow preHea
      "预设房间内部得热（对流部分）"
      annotation (Placement(transformation(extent={{90,80},{110,100}})));

    // 从 MAT 文件读取的内部得热时间序列：
    // MAT 文件 Q_int.mat 内含变量 Q_int (1440×2)：[time[s], Q[W]]
    Modelica.Blocks.Sources.CombiTimeTable timTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/Q_int.mat",
      tableName     = "Q_int",
      columns       = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "内部得热时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{32,80},{52,100}})));

    // ============================================================================
    // 散热器及水侧传感器
    // ============================================================================

    Buildings.Fluid.HeatExchangers.Radiators.RadiatorEN442_2 rad(
      redeclare package Medium = MediumW,
      energyDynamics  = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start         = TIni,
      fraRad=0.35,
      Q_flow_nominal = QRad_flow_nominal,
      T_a_nominal     = TRadSup_nominal,
      T_b_nominal     = TRadRet_nominal,
      m_flow_nominal  = mHeaPum_flow_nominal)
      "水侧散热器（EN442-2 标准模型）"
      annotation (Placement(transformation(extent={{26,-22},{46,-2}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temSup(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "供水温度传感器（至散热器前）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-30})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temRet(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "回水温度传感器（散热器后）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=270,
        origin={70,-30})));

    // ============================================================================
    // 水侧循环水泵与管道
    // ============================================================================

    Buildings.Fluid.Movers.FlowControlled_m_flow pumHeaPum(
      redeclare package Medium = MediumW,
      T_start        = TIni,
      m_flow_nominal = mHeaPum_flow_nominal,
      m_flow_start   = 0.85,
      nominalValuesDefineDefaultPressureCurve = true,
      use_riseTime   = false,
      energyDynamics = Modelica.Fluid.Types.Dynamics.SteadyState)
      "散热器侧循环水泵"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-96})));

    Buildings.Fluid.FixedResistances.Pipe pipeSupply(
      redeclare package Medium = MediumW,
      length         = pipeLengthSupply,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "带保温的供水管及相应热损失"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-60})));

    Buildings.Fluid.FixedResistances.Pipe pipeReturn(
      redeclare package Medium = MediumW,
      length         = pipeLengthReturn,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "带保温的回水管及相应热损失"
      annotation (Placement(transformation(
        extent={{10,-10},{-10,10}},
        rotation=90,
        origin={72,-62})));

    Modelica.Blocks.Sources.Constant const1(k=mHeaPum_flow_real)
      "水侧水泵质量流量设定"
      annotation (Placement(transformation(extent={{-154,-106},{-134,-86}})));

    // ============================================================================
    // 气象边界条件与室外环境
    // ============================================================================

    // MAT 文件 T_out.mat 内含变量 T_out (1440×2)：[time[s], T_out[K 或 °C]]
    Modelica.Blocks.Sources.CombiTimeTable TOutTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/beiquzhu/20250115/TOut.mat",
      tableName     = "TOut",
      columns       = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "室外温度时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{-244,40},{-224,60}})));

    Buildings.HeatTransfer.Sources.PrescribedTemperature TOut
      "室外温度边界（供管道与房间外墙使用）"
      annotation (Placement(transformation(extent={{-154,34},{-134,54}})));

    // ============================================================================
    // 空气源热泵蒸发器侧（风机与边界）
    // ============================================================================

    // ============================================================================
    // 热泵机组与水侧压力边界
    // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable TSupTab(
      tableOnFile = true,
      fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/beiquzhu/20250115/TSup.mat",
      tableName = "TSup",
      columns = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      annotation (Placement(transformation(extent={{-244,6},{-224,26}})));

      Modelica.Blocks.Sources.CombiTimeTable TRetTab(
      tableOnFile = true,
      fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/beiquzhu/20250115/TRet.mat",
      tableName = "TRet",
      columns = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      annotation (Placement(transformation(extent={{-244,-26},{-224,-6}})));

    Buildings.Fluid.Sources.Boundary_pT RetSink(redeclare package Medium =
          MediumW, nPorts=1) "水侧压力边界与热膨胀容"
      annotation (Placement(transformation(extent={{116,-154},{96,-134}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPOut(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器出口水温传感器"
      annotation (Placement(transformation(extent={{-50,-146},{-30,-126}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPIn(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器入口水温传感器"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=-90,
        origin={72,-94})));

    // ============================================================================
    // 房间 RC 模型与辐射/对流耦合
    // ============================================================================

    Modelica.Blocks.Sources.Constant solRadConst[2](k=0)
      "简化：两朝向窗面太阳辐射取 0"
      annotation (Placement(transformation(extent={{-92,70},{-72,90}})));

    Buildings.ThermalZones.ReducedOrder.RC.OneElement room(
      redeclare package Medium = MediumA,
      energyDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start             = 273.15 + 20,
      nOrientations       = 2,
      AExt                = {10000, 2000},
      AWin                = {600,   600},
      ATransparent        = {600,   600},
      hConWin             = 2.7,
      RWin                = 1.66e-4,
      gWin                = 0.4,
      ratioWinConRad      = 0.09,
      indoorPortWin       = false,
      indoorPortExtWalls  = false,
      hConExt             = 8.7,
      RExt                = {1.0e-5},
      RExtRem             = 0.1e-7,
      CExt                = {6e8},
      nExt                = 1,
      VAir                = 80000,
      hRad                = 5.0)
      "大型建筑RC模型"
      annotation (Placement(transformation(extent={{-18,18},{30,54}})));
                                          // 20 °C

      // 面积（按 Table A1）              // m2
                                               // m2
                                               // m2

      // 窗/辐射/对流参数（按 Table A1）
                                               // W/m2K
                                               // K/W

      // 外墙对流与 RC（按 Table A1）  // W/m2K
                                               // K/W
                                               // K/W
                                               // J/K

      // 室内空气体积与线性化辐射（按 Table A1）
                                               // m3
                                                // W/m2K

    Modelica.Blocks.Sources.RealExpression TOut_K(y=TOutTab.y[1] + 273.15)
      annotation (Placement(transformation(extent={{-212,34},{-192,54}})));
    Modelica.Blocks.Sources.RealExpression TOut_K1(y=TSupTab.y[1] + 273.15)
      annotation (Placement(transformation(extent={{-18,-108},{-38,-88}})));
    Buildings.Fluid.Sources.Boundary_pT ambAirSource(
      redeclare package Medium = MediumA,
      use_T_in=true,
      use_p_in=true,
      nPorts=1)
      "蒸发器环境空气入口边界"
      annotation (Placement(transformation(extent={{-126,-178},{-106,-158}})));
    Modelica.Blocks.Sources.Constant ambPressure(k=101325)
      "大气压力常数（空气边界用）"
      annotation (Placement(transformation(extent={{-206,-162},{-186,-142}})));
    Buildings.Fluid.Movers.FlowControlled_m_flow fan(
      redeclare package Medium = MediumA,
      m_flow_nominal=mAir_flow_nominal,
      m_flow_start=0.85,
      nominalValuesDefineDefaultPressureCurve=true,
      use_riseTime=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState)
      "蒸发器侧送风机"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=0,
        origin={-64,-168})));
    Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
      redeclare package Medium1 = MediumW,
      redeclare package Medium2 = MediumA,
      m1_flow_nominal=mHeaPum_flow_nominal,
      m2_flow_nominal=mAir_flow_nominal,
      show_T=true,
      dp1_nominal=2000,
      dp2_nominal=200,
      energyDynamics=Modelica.Fluid.Types.Dynamics.FixedInitial,
      QCon_flow_nominal=QHea_flow_nominal,
      dTEva_nominal=dTEVa_nominal,
      dTCon_nominal=dTCon_nominal,
      use_eta_Carnot_nominal=true,
      T1_start=TIni)
      "空气源热泵（Carnot 模型，给定冷凝温度）"
      annotation (Placement(transformation(extent={{24,-160},{4,-140}})));
    Buildings.Fluid.Sources.Boundary_pT ambAirSink(redeclare package Medium =
          MediumA, nPorts=1)
      "蒸发器环境空气出口边界"
      annotation (Placement(transformation(extent={{114,-184},{94,-164}})));
    Modelica.Blocks.Sources.Constant const3(k=mAir_flow_nominal)
      "空气侧风机质量流量设定"
      annotation (Placement(transformation(extent={{-102,-146},{-82,-126}})));
    Modelica.Blocks.Math.UnitConversions.To_degC to_degC
      annotation (Placement(transformation(extent={{114,-102},{134,-82}})));
    Modelica.Blocks.Sources.Step step(
      height=Tstep_fin - Tstep_ini,
      offset=Tstep_ini,
      startTime=tStep)
      annotation (Placement(transformation(extent={{6,-120},{26,-100}})));
    // ====== 供水管的热损失衰减因子 alpha_s 及 U*A_surf ======
    parameter Modelica.Units.SI.SpecificHeatCapacity cw = 4180
      "水的定压比热（近似常数）";

    // 避免数值上出现除零 / log(<=0)，给一个微小下限
    parameter Real epsAlpha = 1e-6;

    // 供水管入口 / 出口相对环境的温度比 值，即 alpha_s
    Modelica.Blocks.Sources.RealExpression alpha_s_sup(
      y = max(epsAlpha,
              (temSup.T   - TOut.T) /
              (temHPOut.T - TOut.T)))
      "供水管瞬时衰减因子 alpha_s \\in (0,1]";

    // 用公式 UA = - m_dot * c_w * ln(alpha_s) 反解出 U*A_surf
    Modelica.Blocks.Sources.RealExpression UA_surf_sup(
      y = -pumHeaPum.m_flow * cw * Modelica.Math.log(alpha_s_sup.y))
      "供水管对应的 U*A_surf（基于仿真结果）";

  equation

    // 记录阶跃发生时间  t_step
    when (not pre(gotStep)) and time >= tStep then
      t_step  = time;
      gotStep = true;
    end when;

    // 记录散热器入口温度第一次超过 63.2% 的时刻 t_632
    when pre(gotStep) and (not pre(got632)) and (temSup.T >= Ttarget_632.y) then
      t_632  = time;
      tau_63 = t_632 - t_step;
      got632 = true;
    end when;

    // ============================================================================
    // 内部得热与外气温数据连接
    // ============================================================================

    // 内部得热：CombiTimeTable → PrescribedHeatFlow

    // 外气温：CombiTimeTable → 室外温度边界 TOut

    // 外气温：CombiTimeTable → 蒸发器入口空气边界温度

    // ============================================================================
    // 水侧：热泵 → 水泵 → 供水管 → 散热器 → 回水管 → 热泵
    // ============================================================================

    connect(pumHeaPum.port_b, pipeSupply.port_a)
      annotation (Line(points={{-70,-86},{-70,-70}}, color={0,127,255}));

    connect(pipeSupply.port_b, temSup.port_a)
      annotation (Line(points={{-70,-50},{-70,-40}}, color={0,127,255}));

    connect(temSup.port_b, rad.port_a) annotation (Line(
        points={{-70,-20},{-70,-12},{26,-12}},
        color={0,127,255},
        smooth=Smooth.None));

    connect(rad.port_b, temRet.port_a)
      annotation (Line(points={{46,-12},{70,-12},{70,-20}},
                                                        color={0,127,255}));

    connect(temRet.port_b, pipeReturn.port_a)
      annotation (Line(points={{70,-40},{70,-42},{72,-42},{72,-52}},
                                                   color={0,127,255}));

    connect(pipeReturn.port_b, temHPIn.port_a)
      annotation (Line(points={{72,-72},{72,-84}}, color={0,127,255}));

    connect(const1.y, pumHeaPum.m_flow_in)
      annotation (Line(points={{-133,-96},{-82,-96}},   color={0,0,127}));

    connect(temHPOut.port_a, pumHeaPum.port_a) annotation (Line(
        points={{-50,-136},{-70,-136},{-70,-106}},
        color={0,127,255}));

    // ============================================================================
    // 空气源侧：环境空气 → 风机 → 热泵蒸发器 → 环境空气
    // ============================================================================

    // ============================================================================
    // 管道与房间对室外环境的热交换
    // ============================================================================

    connect(TOut.port, pipeSupply.heatPort) annotation (Line(
        points={{-134,44},{-88,44},{-88,-60},{-75,-60}},
        color={191,0,0}));

    connect(pipeReturn.heatPort, TOut.port)
      annotation (Line(points={{67,-62},{-54,-62},{-54,44},{-134,44}},
                                                             color={191,0,0}));

    connect(TOut.port, room.extWall) annotation (Line(
        points={{-134,44},{-26,44},{-26,32},{-18,32}},
        color={191,0,0}));

    connect(TOut.port, room.window) annotation (Line(
        points={{-134,44},{-26,44},{-26,40},{-18,40}},
        color={191,0,0}));

    // ============================================================================
    // 热泵控制与房间内部得热耦合
    // ============================================================================

    connect(solRadConst.y, room.solRad) annotation (Line(
        points={{-71,80},{-26,80},{-26,51},{-19,51}},
        color={0,0,127}));

    connect(rad.heatPortCon, room.intGainsConv) annotation (Line(
        points={{34,-4.8},{34,40},{30,40}},
        color={191,0,0}));

    connect(rad.heatPortRad, room.intGainsRad) annotation (Line(
        points={{38,-4.8},{38,44},{30,44}},
        color={191,0,0}));

    connect(TOut_K.y, TOut.T) annotation (Line(points={{-191,44},{-156,44}},
                       color={0,0,127}));
    connect(preHea.port, room.intGainsConv) annotation (Line(points={{110,90},{134,
            90},{134,40},{30,40}}, color={191,0,0}));
    connect(timTab.y[1], preHea.Q_flow)
      annotation (Line(points={{53,90},{90,90}}, color={0,0,127}));
    connect(TOut_K.y, ambAirSource.T_in) annotation (Line(points={{-191,44},{-164,
            44},{-164,-164},{-128,-164}}, color={0,0,127}));
    connect(ambPressure.y, ambAirSource.p_in) annotation (Line(points={{-185,-152},
            {-138,-152},{-138,-160},{-128,-160}}, color={0,0,127}));
    connect(temHPOut.port_b, heaPum.port_b1) annotation (Line(points={{-30,-136},{
            -2,-136},{-2,-144},{4,-144}}, color={0,127,255}));
    connect(temHPIn.port_b, heaPum.port_a1) annotation (Line(points={{72,-104},{72,
            -144},{24,-144}}, color={0,127,255}));
    connect(RetSink.ports[1], heaPum.port_a1)
      annotation (Line(points={{96,-144},{24,-144}}, color={0,127,255}));
    connect(ambAirSource.ports[1], fan.port_a)
      annotation (Line(points={{-106,-168},{-74,-168}}, color={0,127,255}));
    connect(fan.port_b, heaPum.port_a2) annotation (Line(points={{-54,-168},{-2,-168},
            {-2,-156},{4,-156}}, color={0,127,255}));
    connect(heaPum.port_b2, ambAirSink.ports[1]) annotation (Line(points={{24,-156},
            {88,-156},{88,-174},{94,-174}}, color={0,127,255}));
    connect(const3.y, fan.m_flow_in) annotation (Line(points={{-81,-136},{-72,-136},
            {-72,-148},{-64,-148},{-64,-156}}, color={0,0,127}));
    connect(temHPIn.T, to_degC.u) annotation (Line(points={{83,-94},{104,-94},{104,
            -92},{112,-92}}, color={0,0,127}));
    connect(step.y, heaPum.TSet) annotation (Line(points={{27,-110},{32,-110},{32,
            -134},{26,-134},{26,-141}}, color={0,0,127}));
    annotation (
      Icon(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,120}})),
      Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,
              120}})),
      experiment(
        StopTime=86400,
        __Dymola_NumberOfIntervals=1440,
        __Dymola_Algorithm="Dassl"));
  end Pipe_cal;

  model WithoutHP "2025年1月15至31日的数据验证,无热泵"
    extends Modelica.Icons.Example;

    // ============================================================================
    // 介质定义
    // ============================================================================

    replaceable package MediumA = Buildings.Media.Air
      "空气侧介质模型";
    replaceable package MediumW = Buildings.Media.Water
      "水侧介质模型";

    // ============================================================================
    // 设计工况与房间参数
    // ============================================================================

    // ---------------------- 散热器与热泵额定工况 ----------------------

    parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 1735.2e3
      "热泵冷凝器（供热侧）额定热流量";
    parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 5
      "冷凝器设计供回水温差（约 5 K）";
    parameter Modelica.Units.SI.TemperatureDifference dTEVa_nominal = -5
      "蒸发器设计进出水温差（约 5 K，符号为负）";

    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
        QHea_flow_nominal/4200/dTCon_nominal
      "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 72
      "热泵水侧实际质量流量";
    parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 180
      "蒸发器空气侧额定质量流量";
    parameter Modelica.Units.SI.VolumeFlowRate VAir_flow_nominal = mAir_flow_nominal/1.2
      "蒸发器空气侧额定体积流量（按 ρ≈1.2 kg/m³）";

    parameter Modelica.Units.SI.HeatFlowRate QRad_flow_nominal = QHea_flow_nominal*0.9
      "散热器额定热流量15881.9";
    parameter Modelica.Units.SI.Temperature TRadSup_nominal = 273.15 + 40
      "散热器额定供水温度";
    parameter Modelica.Units.SI.Temperature TRadRet_nominal = 273.15 + 35
      "散热器额定回水温度";
    parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
      "系统供回水初始温度";
    parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 20
      "系统室内初始温度";

    // ---------------------------- 房间与空气 ----------------------------

    parameter Real s = QHea_flow_nominal/18000;
    parameter Modelica.Units.SI.Area A_floor = 500 * s * 2 "建筑面积 (m²)";
    parameter Modelica.Units.SI.Height H_floor = 8 "层高 (m)";
    parameter Modelica.Units.SI.Volume V = A_floor*H_floor
      "房间体积（长×宽×高）";
    parameter Modelica.Units.SI.MassFlowRate mA_flow_nominal = V*1.2*1.5/3600
      "房间空气额定质量流量（换气次数约 1.5 次/h）";
    parameter Modelica.Units.SI.HeatFlowRate QRooInt_flow = 4000
      "房间内部得热（人员、设备等），用于参考";

    // 基于建筑物理的热阻热容计算

    // 外墙面积估算 (假设方形建筑，4面外墙)
    parameter Modelica.Units.SI.Length L_building = sqrt(A_floor) "建筑边长";
    parameter Modelica.Units.SI.Area A_wall_ext = 4 * L_building * H_floor
      "外墙总面积";

    // 典型商业建筑传热系数 (U值)
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer U_wall = 1.2
      "外墙U值 (W/m²·K) - 普通建筑标准";

    // 计算总热阻 (R = 1/(U×A))
    parameter Modelica.Units.SI.ThermalResistance R_total = 1/(U_wall * A_wall_ext)
      "建筑总热阻";

    // 热容计算 - 基于建筑质量
    parameter Modelica.Units.SI.Density rho_concrete = 2400 "混凝土密度 (kg/m³)";
    parameter Modelica.Units.SI.SpecificHeatCapacity cp_concrete = 1000
      "混凝土比热 (J/kg·K)";
    parameter Modelica.Units.SI.Thickness d_wall = 0.1 "墙体厚度 (m)";

    // 建筑热容 (考虑墙体、楼板等热质量)
    parameter Modelica.Units.SI.HeatCapacity C_total =
      A_wall_ext * d_wall * rho_concrete * cp_concrete * 0.6
      "建筑总热容 (考虑60%有效热质量)";

    // --------- 外墙等效热阻 / 热容（增加缩放因子便于校准） ---------

    parameter Real kR = 0.5
      "外墙整体热阻缩放因子 (>1: 保温更好，热损失更小)";
    parameter Real kC = 1
      "建筑热容缩放因子 (>1: 热惰性更大)";

    parameter Modelica.Units.SI.ThermalResistance RExt_set =
      kR * (3e-4*0.8*1.2*1.4*1.2*1.2 / s)
      "外墙等综合传热热阻（设置值）";

    parameter Modelica.Units.SI.ThermalResistance RExtRem_set =
      kR * (1.2e-4*0.8*1.2*1.4*1.2*1.2 / s)
      "与外界环境的剩余热阻（设置值）";

    parameter Modelica.Units.SI.HeatCapacity CExt_set =
      kC * (1e7*1.2 * s)
      "外墙等热容（设置值，用于 RC 模型）";

    // ============================================================================
    // 管路参数（供回水管）
    // ============================================================================

    parameter Modelica.Units.SI.Length pipeLengthSupply = 750
      "基于典型房间布局的供水管长度";
    parameter Modelica.Units.SI.Length pipeLengthReturn = 750
      "基于典型房间布局的回水管长度";
    parameter Modelica.Units.SI.Diameter pipeDiameter = 0.25
      "可满足约 0.95 kg/s 流量的管径估算值";
    parameter Modelica.Units.SI.Thickness thicknessIns = 0.02
      "保温层厚度 (m)";
    parameter Modelica.Units.SI.ThermalConductivity lambdaIns = 0.03
      "保温材料导热系数 (W/m.K)";

    // ============================================================================
    // 热源与内部得热
    // ============================================================================

    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow preHea
      "预设房间内部得热（对流部分）"
      annotation (Placement(transformation(extent={{90,80},{110,100}})));

    // 从 MAT 文件读取的内部得热时间序列：
    // MAT 文件 Q_int.mat 内含变量 Q_int (1440×2)：[time[s], Q[W]]
    Modelica.Blocks.Sources.CombiTimeTable timTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/Q_int.mat",
      tableName     = "Q_int",
      columns       = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "内部得热时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{32,80},{52,100}})));

    // ============================================================================
    // 散热器及水侧传感器
    // ============================================================================

    Buildings.Fluid.HeatExchangers.Radiators.RadiatorEN442_2 rad(
      redeclare package Medium = MediumW,
      energyDynamics  = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start         = TIni,
      fraRad=0.35,
      Q_flow_nominal = QRad_flow_nominal,
      T_a_nominal     = TRadSup_nominal,
      T_b_nominal     = TRadRet_nominal,
      m_flow_nominal  = mHeaPum_flow_nominal)
      "水侧散热器（EN442-2 标准模型）"
      annotation (Placement(transformation(extent={{26,-22},{46,-2}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temSup(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "供水温度传感器（至散热器前）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-30})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temRet(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "回水温度传感器（散热器后）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=270,
        origin={70,-30})));

    // ============================================================================
    // 水侧循环水泵与管道
    // ============================================================================

    Buildings.Fluid.Movers.FlowControlled_m_flow pumHeaPum(
      redeclare package Medium = MediumW,
      T_start        = TIni,
      m_flow_nominal = mHeaPum_flow_nominal,
      m_flow_start   = 0.85,
      nominalValuesDefineDefaultPressureCurve = true,
      use_riseTime   = false,
      energyDynamics = Modelica.Fluid.Types.Dynamics.SteadyState)
      "散热器侧循环水泵"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-96})));

    Buildings.Fluid.FixedResistances.Pipe pipeSupply(
      redeclare package Medium = MediumW,
      length         = pipeLengthSupply,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "带保温的供水管及相应热损失"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-60})));

    Buildings.Fluid.FixedResistances.Pipe pipeReturn(
      redeclare package Medium = MediumW,
      length         = pipeLengthReturn,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "带保温的回水管及相应热损失"
      annotation (Placement(transformation(
        extent={{10,-10},{-10,10}},
        rotation=90,
        origin={72,-62})));

    Modelica.Blocks.Sources.Constant const1(k=mHeaPum_flow_real)
      "水侧水泵质量流量设定"
      annotation (Placement(transformation(extent={{-154,-106},{-134,-86}})));

    // ============================================================================
    // 气象边界条件与室外环境
    // ============================================================================

    // MAT 文件 T_out.mat 内含变量 T_out (1440×2)：[time[s], T_out[K 或 °C]]
    Modelica.Blocks.Sources.CombiTimeTable TOutTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/beiquzhu/0115-0131/TOut.mat",
      tableName     = "TOut",
      columns       = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "室外温度时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{-244,40},{-224,60}})));

    Buildings.HeatTransfer.Sources.PrescribedTemperature TOut
      "室外温度边界（供管道与房间外墙使用）"
      annotation (Placement(transformation(extent={{-154,34},{-134,54}})));

    // ============================================================================
    // 空气源热泵蒸发器侧（风机与边界）
    // ============================================================================

    // ============================================================================
    // 热泵机组与水侧压力边界
    // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable TSupTab(
      tableOnFile = true,
      fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/beiquzhu/0115-0131/TSup.mat",
      tableName = "TSup",
      columns = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      annotation (Placement(transformation(extent={{-244,6},{-224,26}})));

      Modelica.Blocks.Sources.CombiTimeTable TRetTab(
      tableOnFile = true,
      fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/beiquzhu/0115-0131/TRet.mat",
      tableName = "TRet",
      columns = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      annotation (Placement(transformation(extent={{-244,-26},{-224,-6}})));

    Buildings.Fluid.Sources.Boundary_pT RetSink(redeclare package Medium =
          MediumW, nPorts=1) "水侧压力边界与热膨胀容"
      annotation (Placement(transformation(extent={{108,-150},{88,-130}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPOut(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器出口水温传感器"
      annotation (Placement(transformation(extent={{-50,-146},{-30,-126}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPIn(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器入口水温传感器"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=-90,
        origin={72,-94})));

    // ============================================================================
    // 房间 RC 模型与辐射/对流耦合
    // ============================================================================

    Modelica.Blocks.Sources.Constant solRadConst[2](k=0)
      "简化：两朝向窗面太阳辐射取 0"
      annotation (Placement(transformation(extent={{-92,70},{-72,90}})));

    Buildings.ThermalZones.ReducedOrder.RC.OneElement room(
      redeclare package Medium = MediumA,
      energyDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start             = 273.15 + 20,
      nOrientations       = 2,
      AExt                = {10000, 2000},
      AWin                = {600,   600},
      ATransparent        = {600,   600},
      hConWin             = 2.7,
      RWin                = 1.66e-4,
      gWin                = 0.4,
      ratioWinConRad      = 0.09,
      indoorPortWin       = false,
      indoorPortExtWalls  = false,
      hConExt             = 8.7,
      RExt                = {0.98e-5},
      RExtRem             = 0.1e-7,
      CExt                = {6e8},
      nExt                = 1,
      VAir                = 80000,
      hRad                = 5.0)
      "大型建筑RC模型"
      annotation (Placement(transformation(extent={{-18,18},{30,54}})));
                                          // 20 °C

      // 面积（按 Table A1）              // m2
                                               // m2
                                               // m2

      // 窗/辐射/对流参数（按 Table A1）
                                               // W/m2K
                                               // K/W

      // 外墙对流与 RC（按 Table A1）  // W/m2K
                                               // K/W
                                               // K/W
                                               // J/K

      // 室内空气体积与线性化辐射（按 Table A1）
                                               // m3
                                                // W/m2K

    Modelica.Blocks.Sources.RealExpression TOut_K(y=TOutTab.y[1] + 273.15)
      annotation (Placement(transformation(extent={{-212,34},{-192,54}})));
    Modelica.Blocks.Sources.RealExpression TOut_K1(y=TSupTab.y[1] + 273.15)
      annotation (Placement(transformation(extent={{56,-124},{36,-104}})));
    Modelica.Blocks.Math.UnitConversions.To_degC to_degC
      annotation (Placement(transformation(extent={{114,-102},{134,-82}})));
    Buildings.Fluid.Sources.Boundary_pT SupSou(
      redeclare package Medium = MediumW,
      use_T_in=true,
      nPorts=1) "供水源"
      annotation (Placement(transformation(extent={{18,-150},{-2,-130}})));
  equation
    // ============================================================================
    // 内部得热与外气温数据连接
    // ============================================================================

    // 内部得热：CombiTimeTable → PrescribedHeatFlow

    // 外气温：CombiTimeTable → 室外温度边界 TOut

    // 外气温：CombiTimeTable → 蒸发器入口空气边界温度

    // ============================================================================
    // 水侧：热泵 → 水泵 → 供水管 → 散热器 → 回水管 → 热泵
    // ============================================================================

    connect(pumHeaPum.port_b, pipeSupply.port_a)
      annotation (Line(points={{-70,-86},{-70,-70}}, color={0,127,255}));

    connect(pipeSupply.port_b, temSup.port_a)
      annotation (Line(points={{-70,-50},{-70,-40}}, color={0,127,255}));

    connect(temSup.port_b, rad.port_a) annotation (Line(
        points={{-70,-20},{-70,-12},{26,-12}},
        color={0,127,255},
        smooth=Smooth.None));

    connect(rad.port_b, temRet.port_a)
      annotation (Line(points={{46,-12},{70,-12},{70,-20}},
                                                        color={0,127,255}));

    connect(temRet.port_b, pipeReturn.port_a)
      annotation (Line(points={{70,-40},{70,-42},{72,-42},{72,-52}},
                                                   color={0,127,255}));

    connect(pipeReturn.port_b, temHPIn.port_a)
      annotation (Line(points={{72,-72},{72,-84}}, color={0,127,255}));

    connect(const1.y, pumHeaPum.m_flow_in)
      annotation (Line(points={{-133,-96},{-82,-96}},   color={0,0,127}));

    connect(temHPOut.port_a, pumHeaPum.port_a) annotation (Line(
        points={{-50,-136},{-70,-136},{-70,-106}},
        color={0,127,255}));

    // ============================================================================
    // 空气源侧：环境空气 → 风机 → 热泵蒸发器 → 环境空气
    // ============================================================================

    // ============================================================================
    // 管道与房间对室外环境的热交换
    // ============================================================================

    connect(TOut.port, pipeSupply.heatPort) annotation (Line(
        points={{-134,44},{-88,44},{-88,-60},{-75,-60}},
        color={191,0,0}));

    connect(pipeReturn.heatPort, TOut.port)
      annotation (Line(points={{67,-62},{-54,-62},{-54,44},{-134,44}},
                                                             color={191,0,0}));

    connect(TOut.port, room.extWall) annotation (Line(
        points={{-134,44},{-26,44},{-26,32},{-18,32}},
        color={191,0,0}));

    connect(TOut.port, room.window) annotation (Line(
        points={{-134,44},{-26,44},{-26,40},{-18,40}},
        color={191,0,0}));

    // ============================================================================
    // 热泵控制与房间内部得热耦合
    // ============================================================================

    connect(solRadConst.y, room.solRad) annotation (Line(
        points={{-71,80},{-26,80},{-26,51},{-19,51}},
        color={0,0,127}));

    connect(rad.heatPortCon, room.intGainsConv) annotation (Line(
        points={{34,-4.8},{34,40},{30,40}},
        color={191,0,0}));

    connect(rad.heatPortRad, room.intGainsRad) annotation (Line(
        points={{38,-4.8},{38,44},{30,44}},
        color={191,0,0}));

    connect(TOut_K.y, TOut.T) annotation (Line(points={{-191,44},{-156,44}},
                       color={0,0,127}));
    connect(preHea.port, room.intGainsConv) annotation (Line(points={{110,90},{134,
            90},{134,40},{30,40}}, color={191,0,0}));
    connect(timTab.y[1], preHea.Q_flow)
      annotation (Line(points={{53,90},{90,90}}, color={0,0,127}));
    connect(temHPIn.T, to_degC.u) annotation (Line(points={{83,-94},{104,-94},{104,
            -92},{112,-92}}, color={0,0,127}));
    connect(temHPOut.port_b, SupSou.ports[1]) annotation (Line(points={{-30,-136},
            {-8,-136},{-8,-140},{-2,-140}}, color={0,127,255}));
    connect(TOut_K1.y, SupSou.T_in) annotation (Line(points={{35,-114},{30,-114},{
            30,-136},{20,-136}}, color={0,0,127}));
    connect(temHPIn.port_b, RetSink.ports[1]) annotation (Line(points={{72,-104},{
            72,-140},{88,-140}}, color={0,127,255}));
    annotation (
      Icon(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,120}})),
      Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,
              120}})),
      experiment(
        StopTime=1468800,
        Interval=3600,
        __Dymola_Algorithm="Dassl"));
  end WithoutHP;

  model Main_TCon "2025年1月15至31日的数据验证,主模型"
    extends Modelica.Icons.Example;

    // ============================================================================
    // 介质定义
    // ============================================================================

    replaceable package MediumA = Buildings.Media.Air
      "空气侧介质模型";
    replaceable package MediumW = Buildings.Media.Water
      "水侧介质模型";

    // ============================================================================
    // 设计工况与房间参数
    // ============================================================================

    // ---------------------- 散热器与热泵额定工况 ----------------------

    parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
      "热泵冷凝器（供热侧）额定热流量";

    parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
      "冷凝器设计供回水温差（约 5 K）";
    parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
      "蒸发器设计进出水温差（约 5 K，符号为负）";

    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
        QHea_flow_nominal/4200/dTCon_nominal
      "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
      "热泵水侧实际质量流量";
    parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
      "蒸发器空气侧额定质量流量";

    parameter Modelica.Units.SI.HeatFlowRate QRad_flow_nominal = QHea_flow_nominal*0.3
      "散热器额定热流量";
    parameter Modelica.Units.SI.Temperature TRadSup_nominal = 273.15 + 40
      "散热器额定供水温度";
    parameter Modelica.Units.SI.Temperature TRadRet_nominal = 273.15 + 38
      "散热器额定回水温度";
    parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
      "系统供回水初始温度";
    parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 20
      "系统室内初始温度";

    // ---------------------------- 房间与空气 ----------------------------

    parameter Modelica.Units.SI.Area A_floor = 10000 "建筑面积 (m²)";
    parameter Modelica.Units.SI.Height H_floor = 3 "层高 (m)";
    parameter Modelica.Units.SI.Volume V = A_floor*H_floor
      "房间体积（长×宽×高）";
    parameter Modelica.Units.SI.MassFlowRate mA_flow_nominal = V*1.2*1.5/3600
      "房间空气额定质量流量（换气次数约 1.5 次/h）";
    parameter Modelica.Units.SI.HeatFlowRate QRooInt_flow = 4000
      "房间内部得热（人员、设备等），用于参考";

    // --------- 外墙等效热阻 / 热容（增加缩放因子便于校准） ---------

    parameter Modelica.Units.SI.ThermalResistance RExt_set =1
      "外墙等综合传热热阻（设置值）";

    parameter Modelica.Units.SI.ThermalResistance RExtRem_set =1
      "与外界环境的剩余热阻（设置值）";

    parameter Modelica.Units.SI.HeatCapacity CExt_set =1
      "外墙等热容（设置值，用于 RC 模型）";

    // ============================================================================
    // 管路参数（供回水管）
    // ============================================================================

    parameter Modelica.Units.SI.Length pipeLengthSupply = 500
      "基于典型房间布局的供水管长度";
    parameter Modelica.Units.SI.Length pipeLengthReturn = 500
      "基于典型房间布局的回水管长度";
    parameter Modelica.Units.SI.Diameter pipeDiameter = 0.25
      "可满足约 0.95 kg/s 流量的管径估算值";
    parameter Modelica.Units.SI.Thickness thicknessIns = 0.01
      "保温层厚度 (m)";
    parameter Modelica.Units.SI.ThermalConductivity lambdaIns = 0.06
      "保温材料导热系数 (W/m.K)";

    // ============================================================================
    // 热源与内部得热
    // ============================================================================

    // 从 MAT 文件读取的内部得热时间序列：
    // MAT 文件 Q_int.mat 内含变量 Q_int (1440×2)：[time[s], Q[W]]
    Modelica.Blocks.Sources.CombiTimeTable timTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/Q_int.mat",
      tableName     = "Q_int",
      columns       = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "内部得热时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{32,80},{52,100}})));

    // ============================================================================
    // 散热器及水侧传感器
    // ============================================================================

    Buildings.Fluid.HeatExchangers.Radiators.RadiatorEN442_2 rad(
      redeclare package Medium = MediumW,
      energyDynamics  = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start         = TIni,
      fraRad=0.35,
      Q_flow_nominal = QRad_flow_nominal,
      T_a_nominal     = TRadSup_nominal,
      T_b_nominal     = TRadRet_nominal,
      m_flow_nominal  = mHeaPum_flow_nominal)
      "水侧散热器（EN442-2 标准模型）"
      annotation (Placement(transformation(extent={{26,-22},{46,-2}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temSup(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "供水温度传感器（至散热器前）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-30})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temRet(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "回水温度传感器（散热器后）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=270,
        origin={70,-30})));

    // ============================================================================
    // 水侧循环水泵与管道
    // ============================================================================

    Buildings.Fluid.Movers.FlowControlled_m_flow pumHeaPum(
      redeclare package Medium = MediumW,
      T_start        = TIni,
      m_flow_nominal = mHeaPum_flow_nominal,
      m_flow_start   = 0.85,
      nominalValuesDefineDefaultPressureCurve = true,
      use_riseTime   = false,
      energyDynamics = Modelica.Fluid.Types.Dynamics.SteadyState)
      "散热器侧循环水泵"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-96})));

    Buildings.Fluid.FixedResistances.Pipe pipeSupply(
      redeclare package Medium = MediumW,
      length         = pipeLengthSupply,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "带保温的供水管及相应热损失"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-60})));

    Buildings.Fluid.FixedResistances.Pipe pipeReturn(
      redeclare package Medium = MediumW,
      length         = pipeLengthReturn,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "带保温的回水管及相应热损失"
      annotation (Placement(transformation(
        extent={{10,-10},{-10,10}},
        rotation=90,
        origin={72,-62})));

    Modelica.Blocks.Sources.Constant const1(k=mHeaPum_flow_real)
      "水侧水泵质量流量设定"
      annotation (Placement(transformation(extent={{-154,-106},{-134,-86}})));

    // ============================================================================
    // 气象边界条件与室外环境
    // ============================================================================

    // MAT 文件 T_out.mat 内含变量 T_out (1440×2)：[time[s], T_out[K 或 °C]]
    Modelica.Blocks.Sources.CombiTimeTable DataTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/2025-01-10/Data_1min.mat",
      tableName     = "Data",
      columns       = {2,3,4,5},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "室外温度时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{-262,94},{-242,114}})));

    Buildings.HeatTransfer.Sources.PrescribedTemperature TOut
      "室外温度边界（供管道与房间外墙使用）"
      annotation (Placement(transformation(extent={{-154,34},{-134,54}})));

    // ============================================================================
    // 空气源热泵蒸发器侧（风机与边界）
    // ============================================================================

    // ============================================================================
    // 热泵机组与水侧压力边界
    // ============================================================================

    Buildings.Fluid.Sources.Boundary_pT RetSink(redeclare package Medium =
          MediumW, nPorts=1) "水侧压力边界与热膨胀容"
      annotation (Placement(transformation(extent={{116,-154},{96,-134}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPOut(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器出口水温传感器"
      annotation (Placement(transformation(extent={{-50,-146},{-30,-126}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPIn(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器入口水温传感器"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=-90,
        origin={72,-94})));

    // ============================================================================
    // 房间 RC 模型与辐射/对流耦合
    // ============================================================================

    Modelica.Blocks.Sources.Constant solRadConst[2](k=0)
      "简化：两朝向窗面太阳辐射取 0"
      annotation (Placement(transformation(extent={{-92,70},{-72,90}})));

    Buildings.ThermalZones.ReducedOrder.RC.OneElement room(
      redeclare package Medium = MediumA,
      energyDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start=TRooIni,
      nOrientations       = 2,
      AExt                = {1820/2,1820/2},
      AWin                = {1200/2,1200/2},
      ATransparent        = {1000/2,1000/2},
      hConWin             = 2.7,
      RWin                = 5.1e-4/4.8/1.3,
      gWin                = 0.4,
      ratioWinConRad      = 0.09,
      indoorPortWin       = false,
      indoorPortExtWalls  = false,
      hConExt             = 8.7,
      RExt                = {1e-2},
      RExtRem             = 1.5e-6,
      CExt                = {1e7},
      nExt                = 1,
      VAir                = V,
      hRad                = 5)
      "大型建筑RC模型"
      annotation (Placement(transformation(extent={{-18,18},{30,54}})));

    Modelica.Blocks.Sources.RealExpression TOut_K(y=DataTab.y[1] + 273.15)
      annotation (Placement(transformation(extent={{-212,34},{-192,54}})));
    Modelica.Blocks.Sources.RealExpression TSup_K(y=DataTab.y[2] + 273.15)
      annotation (Placement(transformation(extent={{56,-124},{36,-104}})));
    Buildings.Fluid.Sources.Boundary_pT ambAirSource(
      redeclare package Medium = MediumA,
      use_T_in=true,
      use_p_in=false,
      nPorts=1)
      "蒸发器环境空气入口边界"
      annotation (Placement(transformation(extent={{-126,-178},{-106,-158}})));
    Buildings.Fluid.Movers.FlowControlled_m_flow fan(
      redeclare package Medium = MediumA,
      m_flow_nominal=mAir_flow_nominal,
      m_flow_start=0.85,
      nominalValuesDefineDefaultPressureCurve=true,
      use_riseTime=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState)
      "蒸发器侧送风机"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=0,
        origin={-64,-168})));
    Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
      redeclare package Medium1 = MediumW,
      redeclare package Medium2 = MediumA,
      m1_flow_nominal=mHeaPum_flow_nominal,
      m2_flow_nominal=mAir_flow_nominal,
      show_T=true,
      dp1_nominal=2000,
      dp2_nominal=200,
      energyDynamics=Modelica.Fluid.Types.Dynamics.FixedInitial,
      QCon_flow_nominal=QHea_flow_nominal,
      dTEva_nominal=dTEva_nominal,
      dTCon_nominal=dTCon_nominal,
      use_eta_Carnot_nominal=true,
      T1_start=TIni)
      "空气源热泵（Carnot 模型，给定冷凝温度）"
      annotation (Placement(transformation(extent={{24,-160},{4,-140}})));
    Buildings.Fluid.Sources.Boundary_pT ambAirSink(redeclare package Medium =
          MediumA, nPorts=1)
      "蒸发器环境空气出口边界"
      annotation (Placement(transformation(extent={{114,-184},{94,-164}})));
    Modelica.Blocks.Sources.Constant const3(k=mAir_flow_nominal)
      "空气侧风机质量流量设定"
      annotation (Placement(transformation(extent={{-102,-146},{-82,-126}})));
    Modelica.Blocks.Math.UnitConversions.To_degC to_degC
      annotation (Placement(transformation(extent={{114,-102},{134,-82}})));
    Modelica.Blocks.Sources.RealExpression TRet(y=DataTab.y[3])
      annotation (Placement(transformation(extent={{-258,60},{-238,80}})));
    Modelica.Blocks.Sources.RealExpression Vdot(y=DataTab.y[4])
      annotation (Placement(transformation(extent={{-122,-84},{-102,-64}})));
  equation
    // ============================================================================
    // 内部得热与外气温数据连接
    // ============================================================================

    // 内部得热：CombiTimeTable → PrescribedHeatFlow

    // 外气温：CombiTimeTable → 室外温度边界 TOut

    // 外气温：CombiTimeTable → 蒸发器入口空气边界温度

    // ============================================================================
    // 水侧：热泵 → 水泵 → 供水管 → 散热器 → 回水管 → 热泵
    // ============================================================================

    connect(pumHeaPum.port_b, pipeSupply.port_a)
      annotation (Line(points={{-70,-86},{-70,-70}}, color={0,127,255}));

    connect(pipeSupply.port_b, temSup.port_a)
      annotation (Line(points={{-70,-50},{-70,-40}}, color={0,127,255}));

    connect(temSup.port_b, rad.port_a) annotation (Line(
        points={{-70,-20},{-70,-12},{26,-12}},
        color={0,127,255},
        smooth=Smooth.None));

    connect(rad.port_b, temRet.port_a)
      annotation (Line(points={{46,-12},{70,-12},{70,-20}},
                                                        color={0,127,255}));

    connect(temRet.port_b, pipeReturn.port_a)
      annotation (Line(points={{70,-40},{70,-42},{72,-42},{72,-52}},
                                                   color={0,127,255}));

    connect(pipeReturn.port_b, temHPIn.port_a)
      annotation (Line(points={{72,-72},{72,-84}}, color={0,127,255}));

    connect(temHPOut.port_a, pumHeaPum.port_a) annotation (Line(
        points={{-50,-136},{-70,-136},{-70,-106}},
        color={0,127,255}));

    // ============================================================================
    // 空气源侧：环境空气 → 风机 → 热泵蒸发器 → 环境空气
    // ============================================================================

    // ============================================================================
    // 管道与房间对室外环境的热交换
    // ============================================================================

    connect(TOut.port, pipeSupply.heatPort) annotation (Line(
        points={{-134,44},{-88,44},{-88,-60},{-75,-60}},
        color={191,0,0}));

    connect(pipeReturn.heatPort, TOut.port)
      annotation (Line(points={{67,-62},{-54,-62},{-54,44},{-134,44}},
                                                             color={191,0,0}));

    // ============================================================================
    // 热泵控制与房间内部得热耦合
    // ============================================================================

    connect(rad.heatPortCon, room.intGainsConv) annotation (Line(
        points={{34,-4.8},{34,40},{30,40}},
        color={191,0,0}));

    connect(rad.heatPortRad, room.intGainsRad) annotation (Line(
        points={{38,-4.8},{38,44},{30,44}},
        color={191,0,0}));

    connect(TOut_K.y, TOut.T) annotation (Line(points={{-191,44},{-156,44}},
                       color={0,0,127}));
    connect(TOut_K.y, ambAirSource.T_in) annotation (Line(points={{-191,44},{-164,
            44},{-164,-164},{-128,-164}}, color={0,0,127}));
    connect(temHPOut.port_b, heaPum.port_b1) annotation (Line(points={{-30,-136},{
            -2,-136},{-2,-144},{4,-144}}, color={0,127,255}));
    connect(temHPIn.port_b, heaPum.port_a1) annotation (Line(points={{72,-104},{72,
            -144},{24,-144}}, color={0,127,255}));
    connect(RetSink.ports[1], heaPum.port_a1)
      annotation (Line(points={{96,-144},{24,-144}}, color={0,127,255}));
    connect(ambAirSource.ports[1], fan.port_a)
      annotation (Line(points={{-106,-168},{-74,-168}}, color={0,127,255}));
    connect(fan.port_b, heaPum.port_a2) annotation (Line(points={{-54,-168},{-2,-168},
            {-2,-156},{4,-156}}, color={0,127,255}));
    connect(heaPum.port_b2, ambAirSink.ports[1]) annotation (Line(points={{24,-156},
            {88,-156},{88,-174},{94,-174}}, color={0,127,255}));
    connect(TSup_K.y, heaPum.TSet)
      annotation (Line(points={{35,-114},{26,-114},{26,-141}}, color={0,0,127}));
    connect(const3.y, fan.m_flow_in) annotation (Line(points={{-81,-136},{-72,-136},
            {-72,-148},{-64,-148},{-64,-156}}, color={0,0,127}));
    connect(temHPIn.T, to_degC.u) annotation (Line(points={{83,-94},{104,-94},{104,
            -92},{112,-92}}, color={0,0,127}));
    connect(solRadConst.y, room.solRad) annotation (Line(points={{-71,80},{-24,80},
            {-24,51},{-19,51}}, color={0,0,127}));
    connect(TOut.port, room.window) annotation (Line(points={{-134,44},{-54,44},{-54,
            40},{-18,40}}, color={191,0,0}));
    connect(TOut.port, room.extWall) annotation (Line(points={{-134,44},{-24,44},{
            -24,32},{-18,32}},                   color={191,0,0}));
    connect(Vdot.y, pumHeaPum.m_flow_in) annotation (Line(points={{-101,-74},{-90,
            -74},{-90,-96},{-82,-96}}, color={0,0,127}));
    annotation (
      Icon(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,120}})),
      Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,
              120}})),
      experiment(
        StopTime=86400,
        __Dymola_Algorithm="Dassl"));
  end Main_TCon;

  package Main_datareverse
    model MainD
      "2025年1月10至15日的数据验证,Main模型"
      extends Modelica.Icons.Example;

      // ============================================================================
      // 介质定义
      // ============================================================================

      replaceable package MediumA = Buildings.Media.Air
        "空气侧介质模型";
      replaceable package MediumW = Buildings.Media.Water
        "水侧介质模型";

      // ============================================================================
      // 设计工况与房间参数
      // ============================================================================

      // ---------------------- 散热器与热泵额定工况 ----------------------

      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 480e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEVa_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";

      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";


      parameter Modelica.Units.SI.HeatFlowRate QRad_flow_nominal = QHea_flow_nominal*0.85
        "散热器额定热流量";
      parameter Modelica.Units.SI.Temperature TRadSup_nominal = 273.15 + 40
        "散热器额定供水温度";
      parameter Modelica.Units.SI.Temperature TRadRet_nominal = 273.15 + 38
        "散热器额定回水温度";
      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 5
        "系统室内初始温度";

      // ---------------------------- 房间与空气 ----------------------------

      parameter Modelica.Units.SI.Area A_floor = 10000 "建筑面积 (m²)";
      parameter Modelica.Units.SI.Height H_floor = 3 "层高 (m)";
      parameter Modelica.Units.SI.Volume V = A_floor*H_floor
        "房间体积（长×宽×高）";
      parameter Modelica.Units.SI.MassFlowRate mA_flow_nominal = V*1.2*1.5/3600
        "房间空气额定质量流量（换气次数约 1.5 次/h）";
      parameter Modelica.Units.SI.HeatFlowRate QRooInt_flow = 4000
        "房间内部得热（人员、设备等），用于参考";


      // --------- 外墙等效热阻 / 热容（增加缩放因子便于校准） ---------

      parameter Modelica.Units.SI.ThermalResistance RExt_set =1
        "外墙等综合传热热阻（设置值）";

      parameter Modelica.Units.SI.ThermalResistance RExtRem_set =1
        "与外界环境的剩余热阻（设置值）";

      parameter Modelica.Units.SI.HeatCapacity CExt_set =1
        "外墙等热容（设置值，用于 RC 模型）";

      // ============================================================================
      // 管路参数（供回水管）
      // ============================================================================

      parameter Modelica.Units.SI.Length pipeLengthSupply = 500
        "基于典型房间布局的供水管长度";
      parameter Modelica.Units.SI.Length pipeLengthReturn = 500
        "基于典型房间布局的回水管长度";
      parameter Modelica.Units.SI.Diameter pipeDiameter = 0.25
        "可满足约 0.95 kg/s 流量的管径估算值";
      parameter Modelica.Units.SI.Thickness thicknessIns = 0.02
        "保温层厚度 (m)";
      parameter Modelica.Units.SI.ThermalConductivity lambdaIns = 0.03
        "保温材料导热系数 (W/m.K)";

      // ============================================================================
      // 热源与内部得热
      // ============================================================================

      // 从 MAT 文件读取的内部得热时间序列：
      // MAT 文件 Q_int.mat 内含变量 Q_int (1440×2)：[time[s], Q[W]]
      Modelica.Blocks.Sources.CombiTimeTable timTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/Q_int.mat",
        tableName     = "Q_int",
        columns       = {2},
        smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "内部得热时间表（从 MAT 文件）"
        annotation (Placement(transformation(extent={{32,80},{52,100}})));

      // ============================================================================
      // 散热器及水侧传感器
      // ============================================================================

      Buildings.Fluid.HeatExchangers.Radiators.RadiatorEN442_2 rad(
        redeclare package Medium = MediumW,
        energyDynamics  = Modelica.Fluid.Types.Dynamics.FixedInitial,
        T_start         = TIni,
        fraRad=0.35,
        Q_flow_nominal = QRad_flow_nominal,
        T_a_nominal     = TRadSup_nominal,
        T_b_nominal     = TRadRet_nominal,
        m_flow_nominal  = mHeaPum_flow_nominal)
        "水侧散热器（EN442-2 标准模型）"
        annotation (Placement(transformation(extent={{26,-22},{46,-2}})));

      Buildings.Fluid.Sensors.TemperatureTwoPort temSup(
        redeclare package Medium = MediumW,
        m_flow_nominal = mHeaPum_flow_nominal,
        T_start        = TIni)
        "供水温度传感器（至散热器前）"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=90,
          origin={-70,-30})));

      Buildings.Fluid.Sensors.TemperatureTwoPort temRet(
        redeclare package Medium = MediumW,
        m_flow_nominal = mHeaPum_flow_nominal,
        T_start        = TIni)
        "回水温度传感器（散热器后）"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=270,
          origin={70,-30})));

      // ============================================================================
      // 水侧循环水泵与管道
      // ============================================================================

      Buildings.Fluid.Movers.FlowControlled_m_flow pumHeaPum(
        redeclare package Medium = MediumW,
        T_start        = TIni,
        m_flow_nominal = mHeaPum_flow_nominal,
        m_flow_start   = 0.85,
        nominalValuesDefineDefaultPressureCurve = true,
        use_riseTime   = false,
        energyDynamics = Modelica.Fluid.Types.Dynamics.SteadyState)
        "散热器侧循环水泵"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=90,
          origin={-70,-96})));

      Buildings.Fluid.FixedResistances.Pipe pipeSupply(
        redeclare package Medium = MediumW,
        length         = pipeLengthSupply,
        diameter       = pipeDiameter,
        thicknessIns   = thicknessIns,
        lambdaIns      = lambdaIns,
        energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
        m_flow_nominal = mHeaPum_flow_nominal,
        dp_nominal     = 500,
        T_start        = TIni)
        "带保温的供水管及相应热损失"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=90,
          origin={-70,-60})));

      Buildings.Fluid.FixedResistances.Pipe pipeReturn(
        redeclare package Medium = MediumW,
        length         = pipeLengthReturn,
        diameter       = pipeDiameter,
        thicknessIns   = thicknessIns,
        lambdaIns      = lambdaIns,
        energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
        m_flow_nominal = mHeaPum_flow_nominal,
        dp_nominal     = 500,
        T_start        = TIni)
        "带保温的回水管及相应热损失"
        annotation (Placement(transformation(
          extent={{10,-10},{-10,10}},
          rotation=90,
          origin={72,-62})));

      Modelica.Blocks.Sources.Constant const1(k=mHeaPum_flow_real)
        "水侧水泵质量流量设定"
        annotation (Placement(transformation(extent={{-154,-106},{-134,-86}})));

      // ============================================================================
      // 气象边界条件与室外环境
      // ============================================================================

      // MAT 文件 T_out.mat 内含变量 T_out (1440×2)：[time[s], T_out[K 或 °C]]
      Modelica.Blocks.Sources.CombiTimeTable TOutTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/20250110-0115/TOut.mat",
        tableName     = "TOut",
        columns       = {2},
        smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "室外温度时间表（从 MAT 文件）"
        annotation (Placement(transformation(extent={{-244,40},{-224,60}})));

      Buildings.HeatTransfer.Sources.PrescribedTemperature TOut
        "室外温度边界（供管道与房间外墙使用）"
        annotation (Placement(transformation(extent={{-154,34},{-134,54}})));

      // ============================================================================
      // 空气源热泵蒸发器侧（风机与边界）
      // ============================================================================

      // ============================================================================
      // 热泵机组与水侧压力边界
      // ============================================================================

        Modelica.Blocks.Sources.CombiTimeTable TSupTab(
        tableOnFile = true,
        fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/20250110-0115/TSup.mat",
        tableName = "TSup",
        columns = {2},
        smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        annotation (Placement(transformation(extent={{-244,6},{-224,26}})));

        Modelica.Blocks.Sources.CombiTimeTable TRetTab(
        tableOnFile = true,
        fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/20250110-0115/TRet.mat",
        tableName = "TRet",
        columns = {2},
        smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        annotation (Placement(transformation(extent={{-244,-26},{-224,-6}})));

      Buildings.Fluid.Sources.Boundary_pT RetSink(redeclare package Medium =
            MediumW, nPorts=1) "水侧压力边界与热膨胀容"
        annotation (Placement(transformation(extent={{116,-154},{96,-134}})));

      Buildings.Fluid.Sensors.TemperatureTwoPort temHPOut(
        redeclare package Medium = MediumW,
        m_flow_nominal = mHeaPum_flow_nominal,
        T_start        = TIni)
        "热泵冷凝器出口水温传感器"
        annotation (Placement(transformation(extent={{-50,-146},{-30,-126}})));

      Buildings.Fluid.Sensors.TemperatureTwoPort temHPIn(
        redeclare package Medium = MediumW,
        m_flow_nominal = mHeaPum_flow_nominal,
        T_start        = TIni)
        "热泵冷凝器入口水温传感器"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=-90,
          origin={72,-94})));

      // ============================================================================
      // 房间 RC 模型与辐射/对流耦合
      // ============================================================================

      Modelica.Blocks.Sources.Constant solRadConst[2](k=0)
        "简化：两朝向窗面太阳辐射取 0"
        annotation (Placement(transformation(extent={{-92,70},{-72,90}})));

      Buildings.ThermalZones.ReducedOrder.RC.OneElement room(
        redeclare package Medium = MediumA,
        energyDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
        T_start=TRooIni,
        nOrientations       = 2,
        AExt                = {1820/2,1820/2},
        AWin                = {980/2,980/2},
        ATransparent        = {980/2,980/2},
        hConWin             = 2.7,
        RWin                = 5.1e-4/4.8/1.3,
        gWin                = 0.4,
        ratioWinConRad      = 0.09,
        indoorPortWin       = false,
        indoorPortExtWalls  = false,
        hConExt             = 8.7,
        RExt                = {3.4e-5},
        RExtRem             = 1.5e-5,
        CExt                = {1e10},
        nExt                = 1,
        VAir                = V,
        hRad                = 5)
        "大型建筑RC模型"
        annotation (Placement(transformation(extent={{-18,18},{30,54}})));

      Modelica.Blocks.Sources.RealExpression TOut_K(y=TOutTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-212,34},{-192,54}})));
      Modelica.Blocks.Sources.RealExpression TOut_K1(y=TSupTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{56,-124},{36,-104}})));
      Buildings.Fluid.Sources.Boundary_pT ambAirSource(
        redeclare package Medium = MediumA,
        use_T_in=true,
        use_p_in=false,
        nPorts=1)
        "蒸发器环境空气入口边界"
        annotation (Placement(transformation(extent={{-126,-178},{-106,-158}})));
      Buildings.Fluid.Movers.FlowControlled_m_flow fan(
        redeclare package Medium = MediumA,
        m_flow_nominal=mAir_flow_nominal,
        m_flow_start=0.85,
        nominalValuesDefineDefaultPressureCurve=true,
        use_riseTime=false,
        energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState)
        "蒸发器侧送风机"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=0,
          origin={-64,-168})));
      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        dp1_nominal=2000,
        dp2_nominal=200,
        energyDynamics=Modelica.Fluid.Types.Dynamics.FixedInitial,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEVa_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=true,
        T1_start=TIni)
        "空气源热泵（Carnot 模型，给定冷凝温度）"
        annotation (Placement(transformation(extent={{24,-160},{4,-140}})));
      Buildings.Fluid.Sources.Boundary_pT ambAirSink(redeclare package Medium =
            MediumA, nPorts=1)
        "蒸发器环境空气出口边界"
        annotation (Placement(transformation(extent={{114,-184},{94,-164}})));
      Modelica.Blocks.Sources.Constant const3(k=mAir_flow_nominal)
        "空气侧风机质量流量设定"
        annotation (Placement(transformation(extent={{-102,-146},{-82,-126}})));
      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{114,-102},{134,-82}})));
    equation
      // ============================================================================
      // 内部得热与外气温数据连接
      // ============================================================================

      // 内部得热：CombiTimeTable → PrescribedHeatFlow

      // 外气温：CombiTimeTable → 室外温度边界 TOut

      // 外气温：CombiTimeTable → 蒸发器入口空气边界温度

      // ============================================================================
      // 水侧：热泵 → 水泵 → 供水管 → 散热器 → 回水管 → 热泵
      // ============================================================================

      connect(pumHeaPum.port_b, pipeSupply.port_a)
        annotation (Line(points={{-70,-86},{-70,-70}}, color={0,127,255}));

      connect(pipeSupply.port_b, temSup.port_a)
        annotation (Line(points={{-70,-50},{-70,-40}}, color={0,127,255}));

      connect(temSup.port_b, rad.port_a) annotation (Line(
          points={{-70,-20},{-70,-12},{26,-12}},
          color={0,127,255},
          smooth=Smooth.None));

      connect(rad.port_b, temRet.port_a)
        annotation (Line(points={{46,-12},{70,-12},{70,-20}},
                                                          color={0,127,255}));

      connect(temRet.port_b, pipeReturn.port_a)
        annotation (Line(points={{70,-40},{70,-42},{72,-42},{72,-52}},
                                                     color={0,127,255}));

      connect(pipeReturn.port_b, temHPIn.port_a)
        annotation (Line(points={{72,-72},{72,-84}}, color={0,127,255}));

      connect(const1.y, pumHeaPum.m_flow_in)
        annotation (Line(points={{-133,-96},{-82,-96}},   color={0,0,127}));

      connect(temHPOut.port_a, pumHeaPum.port_a) annotation (Line(
          points={{-50,-136},{-70,-136},{-70,-106}},
          color={0,127,255}));

      // ============================================================================
      // 空气源侧：环境空气 → 风机 → 热泵蒸发器 → 环境空气
      // ============================================================================

      // ============================================================================
      // 管道与房间对室外环境的热交换
      // ============================================================================

      connect(TOut.port, pipeSupply.heatPort) annotation (Line(
          points={{-134,44},{-88,44},{-88,-60},{-75,-60}},
          color={191,0,0}));

      connect(pipeReturn.heatPort, TOut.port)
        annotation (Line(points={{67,-62},{-54,-62},{-54,44},{-134,44}},
                                                               color={191,0,0}));

      // ============================================================================
      // 热泵控制与房间内部得热耦合
      // ============================================================================

      connect(rad.heatPortCon, room.intGainsConv) annotation (Line(
          points={{34,-4.8},{34,40},{30,40}},
          color={191,0,0}));

      connect(rad.heatPortRad, room.intGainsRad) annotation (Line(
          points={{38,-4.8},{38,44},{30,44}},
          color={191,0,0}));

      connect(TOut_K.y, TOut.T) annotation (Line(points={{-191,44},{-156,44}},
                         color={0,0,127}));
      connect(TOut_K.y, ambAirSource.T_in) annotation (Line(points={{-191,44},{-164,
              44},{-164,-164},{-128,-164}}, color={0,0,127}));
      connect(temHPOut.port_b, heaPum.port_b1) annotation (Line(points={{-30,-136},{
              -2,-136},{-2,-144},{4,-144}}, color={0,127,255}));
      connect(temHPIn.port_b, heaPum.port_a1) annotation (Line(points={{72,-104},{72,
              -144},{24,-144}}, color={0,127,255}));
      connect(RetSink.ports[1], heaPum.port_a1)
        annotation (Line(points={{96,-144},{24,-144}}, color={0,127,255}));
      connect(ambAirSource.ports[1], fan.port_a)
        annotation (Line(points={{-106,-168},{-74,-168}}, color={0,127,255}));
      connect(fan.port_b, heaPum.port_a2) annotation (Line(points={{-54,-168},{-2,-168},
              {-2,-156},{4,-156}}, color={0,127,255}));
      connect(heaPum.port_b2, ambAirSink.ports[1]) annotation (Line(points={{24,-156},
              {88,-156},{88,-174},{94,-174}}, color={0,127,255}));
      connect(TOut_K1.y, heaPum.TSet)
        annotation (Line(points={{35,-114},{26,-114},{26,-141}}, color={0,0,127}));
      connect(const3.y, fan.m_flow_in) annotation (Line(points={{-81,-136},{-72,-136},
              {-72,-148},{-64,-148},{-64,-156}}, color={0,0,127}));
      connect(temHPIn.T, to_degC.u) annotation (Line(points={{83,-94},{104,-94},{104,
              -92},{112,-92}}, color={0,0,127}));
      connect(solRadConst.y, room.solRad) annotation (Line(points={{-71,80},{-24,80},
              {-24,51},{-19,51}}, color={0,0,127}));
      connect(TOut.port, room.window) annotation (Line(points={{-134,44},{-54,44},{-54,
              40},{-18,40}}, color={191,0,0}));
      connect(TOut.port, room.extWall) annotation (Line(points={{-134,44},{-54,44},{
              -54,40},{-24,40},{-24,32},{-18,32}}, color={191,0,0}));
      annotation (
        Icon(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,120}})),
        Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,
                120}})),
        experiment(
          StopTime=518400,
          __Dymola_Algorithm="Dassl"));
    end MainD;

    model MainD2
      "2025年1月15至31日的数据验证,主模型"
      extends Modelica.Icons.Example;

      // ============================================================================
      // 介质定义
      // ============================================================================

      replaceable package MediumA = Buildings.Media.Air
        "空气侧介质模型";
      replaceable package MediumW = Buildings.Media.Water
        "水侧介质模型";

      // ============================================================================
      // 设计工况与房间参数
      // ============================================================================

      // ---------------------- 散热器与热泵额定工况 ----------------------

      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 480e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEVa_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";

      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";


      parameter Modelica.Units.SI.HeatFlowRate QRad_flow_nominal = QHea_flow_nominal*0.65
        "散热器额定热流量";
      parameter Modelica.Units.SI.Temperature TRadSup_nominal = 273.15 + 40
        "散热器额定供水温度";
      parameter Modelica.Units.SI.Temperature TRadRet_nominal = 273.15 + 38
        "散热器额定回水温度";
      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 38
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 22
        "系统室内初始温度";

      // ---------------------------- 房间与空气 ----------------------------

      parameter Modelica.Units.SI.Area A_floor = 10000 "建筑面积 (m²)";
      parameter Modelica.Units.SI.Height H_floor = 3 "层高 (m)";
      parameter Modelica.Units.SI.Volume V = A_floor*H_floor
        "房间体积（长×宽×高）";
      parameter Modelica.Units.SI.MassFlowRate mA_flow_nominal = V*1.2*1.5/3600
        "房间空气额定质量流量（换气次数约 1.5 次/h）";
      parameter Modelica.Units.SI.HeatFlowRate QRooInt_flow = 4000
        "房间内部得热（人员、设备等），用于参考";


      // --------- 外墙等效热阻 / 热容（增加缩放因子便于校准） ---------

      parameter Modelica.Units.SI.ThermalResistance RExt_set =1
        "外墙等综合传热热阻（设置值）";

      parameter Modelica.Units.SI.ThermalResistance RExtRem_set =1
        "与外界环境的剩余热阻（设置值）";

      parameter Modelica.Units.SI.HeatCapacity CExt_set =1
        "外墙等热容（设置值，用于 RC 模型）";

      // ============================================================================
      // 管路参数（供回水管）
      // ============================================================================

      parameter Modelica.Units.SI.Length pipeLengthSupply = 500
        "基于典型房间布局的供水管长度";
      parameter Modelica.Units.SI.Length pipeLengthReturn = 500
        "基于典型房间布局的回水管长度";
      parameter Modelica.Units.SI.Diameter pipeDiameter = 0.25
        "可满足约 0.95 kg/s 流量的管径估算值";
      parameter Modelica.Units.SI.Thickness thicknessIns = 0.02
        "保温层厚度 (m)";
      parameter Modelica.Units.SI.ThermalConductivity lambdaIns = 0.03
        "保温材料导热系数 (W/m.K)";

      // ============================================================================
      // 热源与内部得热
      // ============================================================================

      // 从 MAT 文件读取的内部得热时间序列：
      // MAT 文件 Q_int.mat 内含变量 Q_int (1440×2)：[time[s], Q[W]]
      Modelica.Blocks.Sources.CombiTimeTable timTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/Q_int.mat",
        tableName     = "Q_int",
        columns       = {2},
        smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "内部得热时间表（从 MAT 文件）"
        annotation (Placement(transformation(extent={{32,80},{52,100}})));

      // ============================================================================
      // 散热器及水侧传感器
      // ============================================================================

      Buildings.Fluid.HeatExchangers.Radiators.RadiatorEN442_2 rad(
        redeclare package Medium = MediumW,
        energyDynamics  = Modelica.Fluid.Types.Dynamics.FixedInitial,
        T_start         = TIni,
        fraRad=0.35,
        Q_flow_nominal = QRad_flow_nominal,
        T_a_nominal     = TRadSup_nominal,
        T_b_nominal     = TRadRet_nominal,
        m_flow_nominal  = mHeaPum_flow_nominal)
        "水侧散热器（EN442-2 标准模型）"
        annotation (Placement(transformation(extent={{26,-22},{46,-2}})));

      Buildings.Fluid.Sensors.TemperatureTwoPort temSup(
        redeclare package Medium = MediumW,
        m_flow_nominal = mHeaPum_flow_nominal,
        T_start        = TIni)
        "供水温度传感器（至散热器前）"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=90,
          origin={-70,-30})));

      Buildings.Fluid.Sensors.TemperatureTwoPort temRet(
        redeclare package Medium = MediumW,
        m_flow_nominal = mHeaPum_flow_nominal,
        T_start        = TIni)
        "回水温度传感器（散热器后）"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=270,
          origin={70,-30})));

      // ============================================================================
      // 水侧循环水泵与管道
      // ============================================================================

      Buildings.Fluid.Movers.FlowControlled_m_flow pumHeaPum(
        redeclare package Medium = MediumW,
        T_start        = TIni,
        m_flow_nominal = mHeaPum_flow_nominal,
        m_flow_start   = 0.85,
        nominalValuesDefineDefaultPressureCurve = true,
        use_riseTime   = false,
        energyDynamics = Modelica.Fluid.Types.Dynamics.SteadyState)
        "散热器侧循环水泵"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=90,
          origin={-70,-96})));

      Buildings.Fluid.FixedResistances.Pipe pipeSupply(
        redeclare package Medium = MediumW,
        length         = pipeLengthSupply,
        diameter       = pipeDiameter,
        thicknessIns   = thicknessIns,
        lambdaIns      = lambdaIns,
        energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
        m_flow_nominal = mHeaPum_flow_nominal,
        dp_nominal     = 500,
        T_start        = TIni)
        "带保温的供水管及相应热损失"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=90,
          origin={-70,-60})));

      Buildings.Fluid.FixedResistances.Pipe pipeReturn(
        redeclare package Medium = MediumW,
        length         = pipeLengthReturn,
        diameter       = pipeDiameter,
        thicknessIns   = thicknessIns,
        lambdaIns      = lambdaIns,
        energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
        m_flow_nominal = mHeaPum_flow_nominal,
        dp_nominal     = 500,
        T_start        = TIni)
        "带保温的回水管及相应热损失"
        annotation (Placement(transformation(
          extent={{10,-10},{-10,10}},
          rotation=90,
          origin={72,-62})));

      Modelica.Blocks.Sources.Constant const1(k=mHeaPum_flow_real)
        "水侧水泵质量流量设定"
        annotation (Placement(transformation(extent={{-154,-106},{-134,-86}})));

      // ============================================================================
      // 气象边界条件与室外环境
      // ============================================================================

      // MAT 文件 T_out.mat 内含变量 T_out (1440×2)：[time[s], T_out[K 或 °C]]
      Modelica.Blocks.Sources.CombiTimeTable TOutTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/20250110-0111/TOut.mat",
        tableName     = "TOut",
        columns       = {2},
        smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "室外温度时间表（从 MAT 文件）"
        annotation (Placement(transformation(extent={{-244,40},{-224,60}})));

      Buildings.HeatTransfer.Sources.PrescribedTemperature TOut
        "室外温度边界（供管道与房间外墙使用）"
        annotation (Placement(transformation(extent={{-154,34},{-134,54}})));

      // ============================================================================
      // 空气源热泵蒸发器侧（风机与边界）
      // ============================================================================

      // ============================================================================
      // 热泵机组与水侧压力边界
      // ============================================================================

        Modelica.Blocks.Sources.CombiTimeTable TSupTab(
        tableOnFile = true,
        fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/20250110-0111/TSup.mat",
        tableName = "TSup",
        columns = {2},
        smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        annotation (Placement(transformation(extent={{-244,6},{-224,26}})));

        Modelica.Blocks.Sources.CombiTimeTable TRetTab(
        tableOnFile = true,
        fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/20250110-0111/TRet.mat",
        tableName = "TRet",
        columns = {2},
        smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        annotation (Placement(transformation(extent={{-244,-26},{-224,-6}})));

      Buildings.Fluid.Sources.Boundary_pT RetSink(redeclare package Medium =
            MediumW, nPorts=1) "水侧压力边界与热膨胀容"
        annotation (Placement(transformation(extent={{116,-154},{96,-134}})));

      Buildings.Fluid.Sensors.TemperatureTwoPort temHPOut(
        redeclare package Medium = MediumW,
        m_flow_nominal = mHeaPum_flow_nominal,
        T_start        = TIni)
        "热泵冷凝器出口水温传感器"
        annotation (Placement(transformation(extent={{-50,-146},{-30,-126}})));

      Buildings.Fluid.Sensors.TemperatureTwoPort temHPIn(
        redeclare package Medium = MediumW,
        m_flow_nominal = mHeaPum_flow_nominal,
        T_start        = TIni)
        "热泵冷凝器入口水温传感器"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=-90,
          origin={72,-94})));

      // ============================================================================
      // 房间 RC 模型与辐射/对流耦合
      // ============================================================================

      Modelica.Blocks.Sources.Constant solRadConst[2](k=0)
        "简化：两朝向窗面太阳辐射取 0"
        annotation (Placement(transformation(extent={{-92,70},{-72,90}})));

      Buildings.ThermalZones.ReducedOrder.RC.OneElement room(
        redeclare package Medium = MediumA,
        energyDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
        T_start=TRooIni,
        nOrientations       = 2,
        AExt                = {1820/2,1820/2},
        AWin                = {980/2,980/2},
        ATransparent        = {980/2,980/2},
        hConWin             = 2.7,
        RWin                = 5.1e-4/4.8/1.3,
        gWin                = 0.4,
        ratioWinConRad      = 0.09,
        indoorPortWin       = false,
        indoorPortExtWalls  = false,
        hConExt             = 8.7,
        RExt                = {3.4e-5},
        RExtRem             = 1.5e-5,
        CExt                = {1e10},
        nExt                = 1,
        VAir                = V,
        hRad                = 5)
        "大型建筑RC模型"
        annotation (Placement(transformation(extent={{-18,18},{30,54}})));

      Modelica.Blocks.Sources.RealExpression TOut_K(y=TOutTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-212,34},{-192,54}})));
      Modelica.Blocks.Sources.RealExpression TOut_K1(y=TSupTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{56,-124},{36,-104}})));
      Buildings.Fluid.Sources.Boundary_pT ambAirSource(
        redeclare package Medium = MediumA,
        use_T_in=true,
        use_p_in=false,
        nPorts=1)
        "蒸发器环境空气入口边界"
        annotation (Placement(transformation(extent={{-126,-178},{-106,-158}})));
      Buildings.Fluid.Movers.FlowControlled_m_flow fan(
        redeclare package Medium = MediumA,
        m_flow_nominal=mAir_flow_nominal,
        m_flow_start=0.85,
        nominalValuesDefineDefaultPressureCurve=true,
        use_riseTime=false,
        energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState)
        "蒸发器侧送风机"
        annotation (Placement(transformation(
          extent={{-10,-10},{10,10}},
          rotation=0,
          origin={-64,-168})));
      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        dp1_nominal=2000,
        dp2_nominal=200,
        energyDynamics=Modelica.Fluid.Types.Dynamics.FixedInitial,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEVa_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=true,
        T1_start=TIni)
        "空气源热泵（Carnot 模型，给定冷凝温度）"
        annotation (Placement(transformation(extent={{24,-160},{4,-140}})));
      Buildings.Fluid.Sources.Boundary_pT ambAirSink(redeclare package Medium =
            MediumA, nPorts=1)
        "蒸发器环境空气出口边界"
        annotation (Placement(transformation(extent={{114,-184},{94,-164}})));
      Modelica.Blocks.Sources.Constant const3(k=mAir_flow_nominal)
        "空气侧风机质量流量设定"
        annotation (Placement(transformation(extent={{-102,-146},{-82,-126}})));
      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{114,-102},{134,-82}})));
    equation
      // ============================================================================
      // 内部得热与外气温数据连接
      // ============================================================================

      // 内部得热：CombiTimeTable → PrescribedHeatFlow

      // 外气温：CombiTimeTable → 室外温度边界 TOut

      // 外气温：CombiTimeTable → 蒸发器入口空气边界温度

      // ============================================================================
      // 水侧：热泵 → 水泵 → 供水管 → 散热器 → 回水管 → 热泵
      // ============================================================================

      connect(pumHeaPum.port_b, pipeSupply.port_a)
        annotation (Line(points={{-70,-86},{-70,-70}}, color={0,127,255}));

      connect(pipeSupply.port_b, temSup.port_a)
        annotation (Line(points={{-70,-50},{-70,-40}}, color={0,127,255}));

      connect(temSup.port_b, rad.port_a) annotation (Line(
          points={{-70,-20},{-70,-12},{26,-12}},
          color={0,127,255},
          smooth=Smooth.None));

      connect(rad.port_b, temRet.port_a)
        annotation (Line(points={{46,-12},{70,-12},{70,-20}},
                                                          color={0,127,255}));

      connect(temRet.port_b, pipeReturn.port_a)
        annotation (Line(points={{70,-40},{70,-42},{72,-42},{72,-52}},
                                                     color={0,127,255}));

      connect(pipeReturn.port_b, temHPIn.port_a)
        annotation (Line(points={{72,-72},{72,-84}}, color={0,127,255}));

      connect(const1.y, pumHeaPum.m_flow_in)
        annotation (Line(points={{-133,-96},{-82,-96}},   color={0,0,127}));

      connect(temHPOut.port_a, pumHeaPum.port_a) annotation (Line(
          points={{-50,-136},{-70,-136},{-70,-106}},
          color={0,127,255}));

      // ============================================================================
      // 空气源侧：环境空气 → 风机 → 热泵蒸发器 → 环境空气
      // ============================================================================

      // ============================================================================
      // 管道与房间对室外环境的热交换
      // ============================================================================

      connect(TOut.port, pipeSupply.heatPort) annotation (Line(
          points={{-134,44},{-88,44},{-88,-60},{-75,-60}},
          color={191,0,0}));

      connect(pipeReturn.heatPort, TOut.port)
        annotation (Line(points={{67,-62},{-54,-62},{-54,44},{-134,44}},
                                                               color={191,0,0}));

      // ============================================================================
      // 热泵控制与房间内部得热耦合
      // ============================================================================

      connect(rad.heatPortCon, room.intGainsConv) annotation (Line(
          points={{34,-4.8},{34,40},{30,40}},
          color={191,0,0}));

      connect(rad.heatPortRad, room.intGainsRad) annotation (Line(
          points={{38,-4.8},{38,44},{30,44}},
          color={191,0,0}));

      connect(TOut_K.y, TOut.T) annotation (Line(points={{-191,44},{-156,44}},
                         color={0,0,127}));
      connect(TOut_K.y, ambAirSource.T_in) annotation (Line(points={{-191,44},{-164,
              44},{-164,-164},{-128,-164}}, color={0,0,127}));
      connect(temHPOut.port_b, heaPum.port_b1) annotation (Line(points={{-30,-136},{
              -2,-136},{-2,-144},{4,-144}}, color={0,127,255}));
      connect(temHPIn.port_b, heaPum.port_a1) annotation (Line(points={{72,-104},{72,
              -144},{24,-144}}, color={0,127,255}));
      connect(RetSink.ports[1], heaPum.port_a1)
        annotation (Line(points={{96,-144},{24,-144}}, color={0,127,255}));
      connect(ambAirSource.ports[1], fan.port_a)
        annotation (Line(points={{-106,-168},{-74,-168}}, color={0,127,255}));
      connect(fan.port_b, heaPum.port_a2) annotation (Line(points={{-54,-168},{-2,-168},
              {-2,-156},{4,-156}}, color={0,127,255}));
      connect(heaPum.port_b2, ambAirSink.ports[1]) annotation (Line(points={{24,-156},
              {88,-156},{88,-174},{94,-174}}, color={0,127,255}));
      connect(TOut_K1.y, heaPum.TSet)
        annotation (Line(points={{35,-114},{26,-114},{26,-141}}, color={0,0,127}));
      connect(const3.y, fan.m_flow_in) annotation (Line(points={{-81,-136},{-72,-136},
              {-72,-148},{-64,-148},{-64,-156}}, color={0,0,127}));
      connect(temHPIn.T, to_degC.u) annotation (Line(points={{83,-94},{104,-94},{104,
              -92},{112,-92}}, color={0,0,127}));
      connect(solRadConst.y, room.solRad) annotation (Line(points={{-71,80},{-24,80},
              {-24,51},{-19,51}}, color={0,0,127}));
      connect(TOut.port, room.window) annotation (Line(points={{-134,44},{-54,44},{-54,
              40},{-18,40}}, color={191,0,0}));
      connect(TOut.port, room.extWall) annotation (Line(points={{-134,44},{-20,
              44},{-20,32},{-18,32}},              color={191,0,0}));
      annotation (
        Icon(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,120}})),
        Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,
                120}})),
        experiment(
          StopTime=172800,
          __Dymola_Algorithm="Dassl"));
    end MainD2;
  end Main_datareverse;

  model Main_y
    "2025年1月15至31日的数据验证,主模型"
    extends Modelica.Icons.Example;

    // ============================================================================
    // 介质定义
    // ============================================================================

    replaceable package MediumA = Buildings.Media.Air
      "空气侧介质模型";
    replaceable package MediumW = Buildings.Media.Water
      "水侧介质模型";

    // ============================================================================
    // 设计工况与房间参数
    // ============================================================================

    // ---------------------- 散热器与热泵额定工况 ----------------------

    parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 480e3
      "热泵冷凝器（供热侧）额定热流量";
    parameter Real COP = 3.33;
    parameter Modelica.Units.SI.Power P_nominal = QHea_flow_nominal/COP;
    parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
      "冷凝器设计供回水温差（约 5 K）";
    parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
      "蒸发器设计进出水温差（约 5 K，符号为负）";

    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
        QHea_flow_nominal/4200/dTCon_nominal
      "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
      "热泵水侧实际质量流量";
    parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
      "蒸发器空气侧额定质量流量";

    parameter Modelica.Units.SI.HeatFlowRate QRad_flow_nominal = QHea_flow_nominal*0.3
      "散热器额定热流量";
    parameter Modelica.Units.SI.Temperature TRadSup_nominal = 273.15 + 40
      "散热器额定供水温度";
    parameter Modelica.Units.SI.Temperature TRadRet_nominal = 273.15 + 38
      "散热器额定回水温度";
    parameter Modelica.Units.SI.Temperature TIni = 273.15 + 41
      "系统供回水初始温度";
    parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 20
      "系统室内初始温度";

    // ---------------------------- 房间与空气 ----------------------------

    parameter Modelica.Units.SI.Area A_floor = 10000 "建筑面积 (m²)";
    parameter Modelica.Units.SI.Height H_floor = 3 "层高 (m)";
    parameter Modelica.Units.SI.Volume V = A_floor*H_floor
      "房间体积（长×宽×高）";
    parameter Modelica.Units.SI.MassFlowRate mA_flow_nominal = V*1.2*1.5/3600
      "房间空气额定质量流量（换气次数约 1.5 次/h）";
    parameter Modelica.Units.SI.HeatFlowRate QRooInt_flow = 4000
      "房间内部得热（人员、设备等），用于参考";


    // --------- 外墙等效热阻 / 热容（增加缩放因子便于校准） ---------

    parameter Modelica.Units.SI.ThermalResistance RExt_set =1
      "外墙等综合传热热阻（设置值）";

    parameter Modelica.Units.SI.ThermalResistance RExtRem_set =1
      "与外界环境的剩余热阻（设置值）";

    parameter Modelica.Units.SI.HeatCapacity CExt_set =1
      "外墙等热容（设置值，用于 RC 模型）";

    // ============================================================================
    // 管路参数（供回水管）
    // ============================================================================

    parameter Modelica.Units.SI.Length pipeLengthSupply = 500
      "基于典型房间布局的供水管长度";
    parameter Modelica.Units.SI.Length pipeLengthReturn = 500
      "基于典型房间布局的回水管长度";
    parameter Modelica.Units.SI.Diameter pipeDiameter = 0.25
      "可满足约 0.95 kg/s 流量的管径估算值";
    parameter Modelica.Units.SI.Thickness thicknessIns = 0.01
      "保温层厚度 (m)";
    parameter Modelica.Units.SI.ThermalConductivity lambdaIns = 0.06
      "保温材料导热系数 (W/m.K)";

    // ============================================================================
    // 热源与内部得热
    // ============================================================================

    // 从 MAT 文件读取的内部得热时间序列：
    // MAT 文件 Q_int.mat 内含变量 Q_int (1440×2)：[time[s], Q[W]]
    Modelica.Blocks.Sources.CombiTimeTable timTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/Q_int.mat",
      tableName     = "Q_int",
      columns       = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "内部得热时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{32,80},{52,100}})));

    // ============================================================================
    // 散热器及水侧传感器
    // ============================================================================

    Buildings.Fluid.HeatExchangers.Radiators.RadiatorEN442_2 rad(
      redeclare package Medium = MediumW,
      energyDynamics  = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start         = TIni,
      fraRad=0.35,
      Q_flow_nominal = QRad_flow_nominal,
      T_a_nominal     = TRadSup_nominal,
      T_b_nominal     = TRadRet_nominal,
      m_flow_nominal  = mHeaPum_flow_nominal)
      "水侧散热器（EN442-2 标准模型）"
      annotation (Placement(transformation(extent={{26,-22},{46,-2}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temSup(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "供水温度传感器（至散热器前）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-30})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temRet(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "回水温度传感器（散热器后）"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=270,
        origin={70,-30})));

    // ============================================================================
    // 水侧循环水泵与管道
    // ============================================================================

    Buildings.Fluid.Movers.FlowControlled_m_flow pumHeaPum(
      redeclare package Medium = MediumW,
      T_start        = TIni,
      m_flow_nominal = mHeaPum_flow_nominal,
      m_flow_start   = 0.85,
      nominalValuesDefineDefaultPressureCurve = true,
      use_riseTime   = false,
      energyDynamics = Modelica.Fluid.Types.Dynamics.SteadyState)
      "散热器侧循环水泵"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-96})));

    Buildings.Fluid.FixedResistances.Pipe pipeSupply(
      redeclare package Medium = MediumW,
      length         = pipeLengthSupply,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "带保温的供水管及相应热损失"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-60})));

    Buildings.Fluid.FixedResistances.Pipe pipeReturn(
      redeclare package Medium = MediumW,
      length         = pipeLengthReturn,
      diameter       = pipeDiameter,
      thicknessIns   = thicknessIns,
      lambdaIns      = lambdaIns,
      energyDynamics = Modelica.Fluid.Types.Dynamics.FixedInitial,
      m_flow_nominal = mHeaPum_flow_nominal,
      dp_nominal     = 500,
      T_start        = TIni)
      "带保温的回水管及相应热损失"
      annotation (Placement(transformation(
        extent={{10,-10},{-10,10}},
        rotation=90,
        origin={72,-62})));

    Modelica.Blocks.Sources.Constant const1(k=60)
      "水侧水泵质量流量设定"
      annotation (Placement(transformation(extent={{-130,-110},{-110,-90}})));

    // ============================================================================
    // 气象边界条件与室外环境
    // ============================================================================

    // MAT 文件 T_out.mat 内含变量 T_out (1440×2)：[time[s], T_out[K 或 °C]]
    Modelica.Blocks.Sources.CombiTimeTable DataTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/2025-01-10/Data_1min.mat",
      tableName     = "Data",
      columns       = {2,3,4,5},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "室外温度时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{-262,94},{-242,114}})));

    Buildings.HeatTransfer.Sources.PrescribedTemperature TOut
      "室外温度边界（供管道与房间外墙使用）"
      annotation (Placement(transformation(extent={{-154,34},{-134,54}})));

    // ============================================================================
    // 空气源热泵蒸发器侧（风机与边界）
    // ============================================================================

    // ============================================================================
    // 热泵机组与水侧压力边界
    // ============================================================================

    Buildings.Fluid.Sources.Boundary_pT RetSink(redeclare package Medium =
          MediumW, nPorts=1) "水侧压力边界与热膨胀容"
      annotation (Placement(transformation(extent={{126,-150},{106,-130}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPOut(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器出口水温传感器"
      annotation (Placement(transformation(extent={{-50,-146},{-30,-126}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPIn(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器入口水温传感器"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=-90,
        origin={72,-94})));

    // ============================================================================
    // 房间 RC 模型与辐射/对流耦合
    // ============================================================================

    Modelica.Blocks.Sources.Constant solRadConst[2](k=0)
      "简化：两朝向窗面太阳辐射取 0"
      annotation (Placement(transformation(extent={{-92,70},{-72,90}})));

    Buildings.ThermalZones.ReducedOrder.RC.OneElement room(
      redeclare package Medium = MediumA,
      energyDynamics      = Modelica.Fluid.Types.Dynamics.FixedInitial,
      T_start=TRooIni,
      nOrientations       = 2,
      AExt                = {1000/2,1000/2},
      AWin                = {1000/2,1000/2},
      ATransparent        = {1000/2,1000/2},
      hConWin             = 2.7,
      RWin                = 5.1e-4/5,
      gWin                = 0.4,
      ratioWinConRad      = 0.09,
      indoorPortWin       = false,
      indoorPortExtWalls  = false,
      hConExt             = 15,
      RExt                = {8e-4},
      RExtRem             = 1.5e-5,
      CExt                = {0.5e8},
      nExt                = 1,
      VAir                = V*2,
      hRad                = 5)
      "大型建筑RC模型"
      annotation (Placement(transformation(extent={{-18,18},{30,54}})));

    Modelica.Blocks.Sources.RealExpression TOut_K(y=DataTab.y[1] + 273.15)
      annotation (Placement(transformation(extent={{-212,34},{-192,54}})));
    Modelica.Blocks.Sources.RealExpression TSup_K(y=DataTab.y[2] + 273.15)
      annotation (Placement(transformation(extent={{2,-118},{-18,-98}})));
    Buildings.Fluid.Sources.Boundary_pT ambAirSource(
      redeclare package Medium = MediumA,
      use_T_in=true,
      use_p_in=false,
      nPorts=1)
      "蒸发器环境空气入口边界"
      annotation (Placement(transformation(extent={{-126,-178},{-106,-158}})));
    Buildings.Fluid.Movers.FlowControlled_m_flow fan(
      redeclare package Medium = MediumA,
      m_flow_nominal=mAir_flow_nominal,
      m_flow_start=0.85,
      nominalValuesDefineDefaultPressureCurve=true,
      use_riseTime=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState)
      "蒸发器侧送风机"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=0,
        origin={-64,-168})));
    Buildings.Fluid.Sources.Boundary_pT ambAirSink(redeclare package Medium =
          MediumA, nPorts=1)
      "蒸发器环境空气出口边界"
      annotation (Placement(transformation(extent={{114,-184},{94,-164}})));
    Modelica.Blocks.Sources.Constant const3(k=mAir_flow_nominal)
      "空气侧风机质量流量设定"
      annotation (Placement(transformation(extent={{-102,-146},{-82,-126}})));
    Modelica.Blocks.Math.UnitConversions.To_degC to_degC
      annotation (Placement(transformation(extent={{114,-102},{134,-82}})));
    Modelica.Blocks.Sources.RealExpression TRet(y=DataTab.y[3])
      annotation (Placement(transformation(extent={{-258,60},{-238,80}})));
    Buildings.Fluid.HeatPumps.Carnot_y heaPum(
      redeclare package Medium1 = MediumW,
      redeclare package Medium2 = MediumA,
      m1_flow_nominal=mHeaPum_flow_nominal,
      m2_flow_nominal=mAir_flow_nominal,
      show_T=true,
      dTEva_nominal=dTEva_nominal,
      dTCon_nominal=dTCon_nominal,
      use_eta_Carnot_nominal=false,
      etaCarnot_nominal=0.5,
      COP_nominal=COP,
      TCon_nominal=321.81,
      TEva_nominal=261.15,
      a={1},
      dp1_nominal=2000,
      dp2_nominal=200,
      P_nominal=P_nominal)
      annotation (Placement(transformation(extent={{24,-156},{4,-136}})));
    Modelica.Blocks.Sources.Constant ySet(k=1) "热泵压缩机部分负荷"
      annotation (Placement(transformation(extent={{44,-102},{24,-82}})));
    Modelica.Blocks.Sources.CombiTimeTable yTab(
      tableOnFile = true,
      fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/2025-01-10/Carnot_y/yHP_1min.mat",
      tableName = "yHP",
      columns = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      annotation (Placement(transformation(extent={{-216,94},{-196,114}})));
    Modelica.Blocks.Sources.RealExpression yMeas(y=yTab.y[1])
      annotation (Placement(transformation(extent={{58,-132},{38,-112}})));
  equation
    // ============================================================================
    // 内部得热与外气温数据连接
    // ============================================================================

    // 内部得热：CombiTimeTable → PrescribedHeatFlow

    // 外气温：CombiTimeTable → 室外温度边界 TOut

    // 外气温：CombiTimeTable → 蒸发器入口空气边界温度

    // ============================================================================
    // 水侧：热泵 → 水泵 → 供水管 → 散热器 → 回水管 → 热泵
    // ============================================================================

    connect(pumHeaPum.port_b, pipeSupply.port_a)
      annotation (Line(points={{-70,-86},{-70,-70}}, color={0,127,255}));

    connect(pipeSupply.port_b, temSup.port_a)
      annotation (Line(points={{-70,-50},{-70,-40}}, color={0,127,255}));

    connect(temSup.port_b, rad.port_a) annotation (Line(
        points={{-70,-20},{-70,-12},{26,-12}},
        color={0,127,255},
        smooth=Smooth.None));

    connect(rad.port_b, temRet.port_a)
      annotation (Line(points={{46,-12},{70,-12},{70,-20}},
                                                        color={0,127,255}));

    connect(temRet.port_b, pipeReturn.port_a)
      annotation (Line(points={{70,-40},{70,-42},{72,-42},{72,-52}},
                                                   color={0,127,255}));

    connect(pipeReturn.port_b, temHPIn.port_a)
      annotation (Line(points={{72,-72},{72,-84}}, color={0,127,255}));

    connect(temHPOut.port_a, pumHeaPum.port_a) annotation (Line(
        points={{-50,-136},{-70,-136},{-70,-106}},
        color={0,127,255}));

    // ============================================================================
    // 空气源侧：环境空气 → 风机 → 热泵蒸发器 → 环境空气
    // ============================================================================

    // ============================================================================
    // 管道与房间对室外环境的热交换
    // ============================================================================

    connect(TOut.port, pipeSupply.heatPort) annotation (Line(
        points={{-134,44},{-88,44},{-88,-60},{-75,-60}},
        color={191,0,0}));

    connect(pipeReturn.heatPort, TOut.port)
      annotation (Line(points={{67,-62},{-54,-62},{-54,44},{-134,44}},
                                                             color={191,0,0}));

    // ============================================================================
    // 热泵控制与房间内部得热耦合
    // ============================================================================

    connect(rad.heatPortCon, room.intGainsConv) annotation (Line(
        points={{34,-4.8},{34,40},{30,40}},
        color={191,0,0}));

    connect(rad.heatPortRad, room.intGainsRad) annotation (Line(
        points={{38,-4.8},{38,44},{30,44}},
        color={191,0,0}));

    connect(TOut_K.y, TOut.T) annotation (Line(points={{-191,44},{-156,44}},
                       color={0,0,127}));
    connect(TOut_K.y, ambAirSource.T_in) annotation (Line(points={{-191,44},{-164,
            44},{-164,-164},{-128,-164}}, color={0,0,127}));
    connect(ambAirSource.ports[1], fan.port_a)
      annotation (Line(points={{-106,-168},{-74,-168}}, color={0,127,255}));
    connect(const3.y, fan.m_flow_in) annotation (Line(points={{-81,-136},{-72,-136},
            {-72,-148},{-64,-148},{-64,-156}}, color={0,0,127}));
    connect(temHPIn.T, to_degC.u) annotation (Line(points={{83,-94},{104,-94},{104,
            -92},{112,-92}}, color={0,0,127}));
    connect(solRadConst.y, room.solRad) annotation (Line(points={{-71,80},{-24,80},
            {-24,51},{-19,51}}, color={0,0,127}));
    connect(TOut.port, room.window) annotation (Line(points={{-134,44},{-46,44},{-46,
            40},{-18,40}}, color={191,0,0}));
    connect(TOut.port, room.extWall) annotation (Line(points={{-134,44},{-24,44},{
            -24,32},{-18,32}},                   color={191,0,0}));
    connect(temHPOut.port_b, heaPum.port_b1) annotation (Line(points={{-30,-136},{
            -2,-136},{-2,-140},{4,-140}}, color={0,127,255}));
    connect(fan.port_b, heaPum.port_a2) annotation (Line(points={{-54,-168},{-2,-168},
            {-2,-152},{4,-152}}, color={0,127,255}));
    connect(heaPum.port_b2, ambAirSink.ports[1]) annotation (Line(points={{24,-152},
            {86,-152},{86,-174},{94,-174}}, color={0,127,255}));
    connect(temHPIn.port_b, heaPum.port_a1) annotation (Line(points={{72,-104},{72,
            -140},{24,-140}}, color={0,127,255}));
    connect(heaPum.port_a1, RetSink.ports[1])
      annotation (Line(points={{24,-140},{106,-140}}, color={0,127,255}));
    connect(yMeas.y, heaPum.y)
      annotation (Line(points={{37,-122},{26,-122},{26,-137}}, color={0,0,127}));
    connect(const1.y, pumHeaPum.m_flow_in) annotation (Line(points={{-109,-100},{-92,
            -100},{-92,-96},{-82,-96}}, color={0,0,127}));
    annotation (
      Icon(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,120}})),
      Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,
              120}})),
      experiment(
        StopTime=86400,
        __Dymola_Algorithm="Dassl"));
  end Main_y;

  model OnlyHP
    "2025年1月15至31日的数据验证,主模型"
    extends Modelica.Icons.Example;

    // ============================================================================
    // 介质定义
    // ============================================================================

    replaceable package MediumA = Buildings.Media.Air
      "空气侧介质模型";
    replaceable package MediumW = Buildings.Media.Water
      "水侧介质模型";

    // ============================================================================
    // 设计工况与房间参数
    // ============================================================================

    // ---------------------- 散热器与热泵额定工况 ----------------------

    parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 480e3
      "热泵冷凝器（供热侧）额定热流量";
    parameter Real COP = 4;
    parameter Modelica.Units.SI.Power P_nominal = QHea_flow_nominal/COP;
    parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
      "冷凝器设计供回水温差（约 5 K）";
    parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
      "蒸发器设计进出水温差（约 5 K，符号为负）";

    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
        QHea_flow_nominal/4200/dTCon_nominal
      "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
      "热泵水侧实际质量流量";
    parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
      "蒸发器空气侧额定质量流量";


    parameter Modelica.Units.SI.HeatFlowRate QRad_flow_nominal = QHea_flow_nominal*0.3
      "散热器额定热流量";
    parameter Modelica.Units.SI.Temperature TRadSup_nominal = 273.15 + 40
      "散热器额定供水温度";
    parameter Modelica.Units.SI.Temperature TRadRet_nominal = 273.15 + 38
      "散热器额定回水温度";
    parameter Modelica.Units.SI.Temperature TIni = 273.15 + 41
      "系统供回水初始温度";
    parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 20
      "系统室内初始温度";

    // ---------------------------- 房间与空气 ----------------------------

    parameter Modelica.Units.SI.Area A_floor = 10000 "建筑面积 (m²)";
    parameter Modelica.Units.SI.Height H_floor = 3 "层高 (m)";
    parameter Modelica.Units.SI.Volume V = A_floor*H_floor
      "房间体积（长×宽×高）";
    parameter Modelica.Units.SI.MassFlowRate mA_flow_nominal = V*1.2*1.5/3600
      "房间空气额定质量流量（换气次数约 1.5 次/h）";
    parameter Modelica.Units.SI.HeatFlowRate QRooInt_flow = 4000
      "房间内部得热（人员、设备等），用于参考";


    // --------- 外墙等效热阻 / 热容（增加缩放因子便于校准） ---------

    parameter Modelica.Units.SI.ThermalResistance RExt_set =1
      "外墙等综合传热热阻（设置值）";

    parameter Modelica.Units.SI.ThermalResistance RExtRem_set =1
      "与外界环境的剩余热阻（设置值）";

    parameter Modelica.Units.SI.HeatCapacity CExt_set =1
      "外墙等热容（设置值，用于 RC 模型）";

    // ============================================================================
    // 管路参数（供回水管）
    // ============================================================================

    parameter Modelica.Units.SI.Length pipeLengthSupply = 500
      "基于典型房间布局的供水管长度";
    parameter Modelica.Units.SI.Length pipeLengthReturn = 500
      "基于典型房间布局的回水管长度";
    parameter Modelica.Units.SI.Diameter pipeDiameter = 0.25
      "可满足约 0.95 kg/s 流量的管径估算值";
    parameter Modelica.Units.SI.Thickness thicknessIns = 0.01
      "保温层厚度 (m)";
    parameter Modelica.Units.SI.ThermalConductivity lambdaIns = 0.06
      "保温材料导热系数 (W/m.K)";

    // ============================================================================
    // 热源与内部得热
    // ============================================================================

    // 从 MAT 文件读取的内部得热时间序列：
    // MAT 文件 Q_int.mat 内含变量 Q_int (1440×2)：[time[s], Q[W]]

    // ============================================================================
    // 散热器及水侧传感器
    // ============================================================================

    // ============================================================================
    // 水侧循环水泵与管道
    // ============================================================================

    Buildings.Fluid.Movers.FlowControlled_m_flow pumHeaPum(
      redeclare package Medium = MediumW,
      T_start        = TIni,
      m_flow_nominal = mHeaPum_flow_nominal,
      m_flow_start   = 0.85,
      nominalValuesDefineDefaultPressureCurve = true,
      use_riseTime   = false,
      energyDynamics = Modelica.Fluid.Types.Dynamics.SteadyState)
      "散热器侧循环水泵"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=90,
        origin={-70,-96})));

    // ============================================================================
    // 气象边界条件与室外环境
    // ============================================================================

    // MAT 文件 T_out.mat 内含变量 T_out (1440×2)：[time[s], T_out[K 或 °C]]
    Modelica.Blocks.Sources.CombiTimeTable DataTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/2025-01-10/Data_1min.mat",
      tableName     = "Data",
      columns       = {2,3,4,5},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "室外温度时间表（从 MAT 文件）"
      annotation (Placement(transformation(extent={{-262,94},{-242,114}})));

    // ============================================================================
    // 空气源热泵蒸发器侧（风机与边界）
    // ============================================================================

    // ============================================================================
    // 热泵机组与水侧压力边界
    // ============================================================================

    Buildings.Fluid.Sources.Boundary_pT RetSink(redeclare package Medium =
          MediumW,
      use_T_in=true,
      nPorts=1)              "水侧压力边界与热膨胀容"
      annotation (Placement(transformation(extent={{10,-10},{-10,10}},
          rotation=90,
          origin={72,-40})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPOut(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器出口水温传感器"
      annotation (Placement(transformation(extent={{-50,-146},{-30,-126}})));

    Buildings.Fluid.Sensors.TemperatureTwoPort temHPIn(
      redeclare package Medium = MediumW,
      m_flow_nominal = mHeaPum_flow_nominal,
      T_start        = TIni)
      "热泵冷凝器入口水温传感器"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=-90,
        origin={72,-94})));

    // ============================================================================
    // 房间 RC 模型与辐射/对流耦合
    // ============================================================================

    Modelica.Blocks.Sources.RealExpression TOut_K(y=DataTab.y[1] + 273.15)
      annotation (Placement(transformation(extent={{-240,-174},{-220,-154}})));
    Modelica.Blocks.Sources.RealExpression TSup_K(y=DataTab.y[2] + 273.15)
      annotation (Placement(transformation(extent={{2,-118},{-18,-98}})));
    Buildings.Fluid.Sources.Boundary_pT ambAirSource(
      redeclare package Medium = MediumA,
      use_T_in=true,
      use_p_in=false,
      nPorts=1)
      "蒸发器环境空气入口边界"
      annotation (Placement(transformation(extent={{-126,-178},{-106,-158}})));
    Buildings.Fluid.Movers.FlowControlled_m_flow fan(
      redeclare package Medium = MediumA,
      m_flow_nominal=mAir_flow_nominal,
      m_flow_start=0.85,
      nominalValuesDefineDefaultPressureCurve=true,
      use_riseTime=false,
      energyDynamics=Modelica.Fluid.Types.Dynamics.SteadyState)
      "蒸发器侧送风机"
      annotation (Placement(transformation(
        extent={{-10,-10},{10,10}},
        rotation=0,
        origin={-64,-168})));
    Buildings.Fluid.Sources.Boundary_pT ambAirSink(redeclare package Medium =
          MediumA, nPorts=1)
      "蒸发器环境空气出口边界"
      annotation (Placement(transformation(extent={{114,-184},{94,-164}})));
    Modelica.Blocks.Sources.Constant const3(k=mAir_flow_nominal)
      "空气侧风机质量流量设定"
      annotation (Placement(transformation(extent={{-102,-146},{-82,-126}})));
    Modelica.Blocks.Math.UnitConversions.To_degC to_degC
      annotation (Placement(transformation(extent={{114,-102},{134,-82}})));
    Modelica.Blocks.Sources.RealExpression TRet(y=DataTab.y[3])
      annotation (Placement(transformation(extent={{-258,60},{-238,80}})));
    Modelica.Blocks.Sources.RealExpression Vdot(y=DataTab.y[4])
      annotation (Placement(transformation(extent={{-122,-84},{-102,-64}})));
    Buildings.Fluid.HeatPumps.Carnot_y heaPum(
      redeclare package Medium1 = MediumW,
      redeclare package Medium2 = MediumA,
      m1_flow_nominal=mHeaPum_flow_nominal,
      m2_flow_nominal=mAir_flow_nominal,
      show_T=true,
      dTEva_nominal=dTEva_nominal,
      dTCon_nominal=dTCon_nominal,
      use_eta_Carnot_nominal=false,
      etaCarnot_nominal=0.5,
      COP_nominal=COP,
      TCon_nominal=321.81,
      TEva_nominal=266.15,
      a={1},
      dp1_nominal=2000,
      dp2_nominal=200,
      P_nominal=P_nominal)
      annotation (Placement(transformation(extent={{24,-156},{4,-136}})));
    Modelica.Blocks.Sources.Constant ySet(k=1) "热泵压缩机部分负荷"
      annotation (Placement(transformation(extent={{44,-102},{24,-82}})));
    Modelica.Blocks.Sources.CombiTimeTable yTab(
      tableOnFile = true,
      fileName = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/2025-01-10/Carnot_y/yTab_iter1.mat",
      tableName = "yTab",
      columns = {2},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      annotation (Placement(transformation(extent={{-216,94},{-196,114}})));
    Modelica.Blocks.Sources.RealExpression yMeas(y=yTab.y[1])
      annotation (Placement(transformation(extent={{58,-132},{38,-112}})));
    Buildings.Fluid.Sources.Boundary_pT RetSink1(redeclare package Medium =
          MediumW, nPorts=1) "水侧压力边界与热膨胀容"
      annotation (Placement(transformation(extent={{10,-10},{-10,10}},
          rotation=90,
          origin={-72,-50})));
    Modelica.Blocks.Sources.RealExpression TSup_K1(y=DataTab.y[3] + 273.15)
      annotation (Placement(transformation(extent={{116,-30},{96,-10}})));
  equation
    // ============================================================================
    // 内部得热与外气温数据连接
    // ============================================================================

    // 内部得热：CombiTimeTable → PrescribedHeatFlow

    // 外气温：CombiTimeTable → 室外温度边界 TOut

    // 外气温：CombiTimeTable → 蒸发器入口空气边界温度

    // ============================================================================
    // 水侧：热泵 → 水泵 → 供水管 → 散热器 → 回水管 → 热泵
    // ============================================================================

    connect(temHPOut.port_a, pumHeaPum.port_a) annotation (Line(
        points={{-50,-136},{-70,-136},{-70,-106}},
        color={0,127,255}));

    // ============================================================================
    // 空气源侧：环境空气 → 风机 → 热泵蒸发器 → 环境空气
    // ============================================================================

    // ============================================================================
    // 管道与房间对室外环境的热交换
    // ============================================================================

    // ============================================================================
    // 热泵控制与房间内部得热耦合
    // ============================================================================

    connect(TOut_K.y, ambAirSource.T_in) annotation (Line(points={{-219,-164},{-128,
            -164}},                       color={0,0,127}));
    connect(ambAirSource.ports[1], fan.port_a)
      annotation (Line(points={{-106,-168},{-74,-168}}, color={0,127,255}));
    connect(const3.y, fan.m_flow_in) annotation (Line(points={{-81,-136},{-72,-136},
            {-72,-148},{-64,-148},{-64,-156}}, color={0,0,127}));
    connect(temHPIn.T, to_degC.u) annotation (Line(points={{83,-94},{104,-94},{104,
            -92},{112,-92}}, color={0,0,127}));
    connect(temHPOut.port_b, heaPum.port_b1) annotation (Line(points={{-30,-136},{
            -2,-136},{-2,-140},{4,-140}}, color={0,127,255}));
    connect(fan.port_b, heaPum.port_a2) annotation (Line(points={{-54,-168},{-2,-168},
            {-2,-152},{4,-152}}, color={0,127,255}));
    connect(heaPum.port_b2, ambAirSink.ports[1]) annotation (Line(points={{24,-152},
            {86,-152},{86,-174},{94,-174}}, color={0,127,255}));
    connect(temHPIn.port_b, heaPum.port_a1) annotation (Line(points={{72,-104},{72,
            -140},{24,-140}}, color={0,127,255}));
    connect(Vdot.y, pumHeaPum.m_flow_in) annotation (Line(points={{-101,-74},{-90,
            -74},{-90,-96},{-82,-96}}, color={0,0,127}));
    connect(yMeas.y, heaPum.y)
      annotation (Line(points={{37,-122},{26,-122},{26,-137}}, color={0,0,127}));
    connect(RetSink.ports[1], temHPIn.port_a)
      annotation (Line(points={{72,-50},{72,-84}}, color={0,127,255}));
    connect(pumHeaPum.port_b, RetSink1.ports[1]) annotation (Line(points={{-70,-86},
            {-70,-66},{-72,-66},{-72,-60}}, color={0,127,255}));
    connect(TSup_K1.y, RetSink.T_in)
      annotation (Line(points={{95,-20},{68,-20},{68,-28}}, color={0,0,127}));
    annotation (
      Icon(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,120}})),
      Diagram(coordinateSystem(preserveAspectRatio=false, extent={{-280,-220},{180,
              120}})),
      experiment(
        StopTime=86400,
        __Dymola_Algorithm="Dassl"));
  end OnlyHP;

  model WithAHU

    replaceable package MediumA = Buildings.Media.Air;
    replaceable package MediumW = Buildings.Media.Water;


    // ============================================================================
    // 参数设置
    // ============================================================================


    parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
      "系统供回水初始温度";
    parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 20
      "系统室内初始温度";

    // ---------------------- 热泵额定工况 ----------------------
    parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
      "热泵冷凝器（供热侧）额定热流量";
    parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
      "冷凝器设计供回水温差（约 5 K）";
    parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
      "蒸发器设计进出水温差（约 5 K，符号为负）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
        QHea_flow_nominal/4200/dTCon_nominal
      "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
      "热泵水侧实际质量流量";
    parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
      "蒸发器空气侧额定质量流量";

    // ---------------------- 建筑参数设置 ----------------------
    // (A)几何
    parameter Modelica.Units.SI.Area AFlo = 10000;
    parameter Modelica.Units.SI.Volume VAir = 30000;

    parameter Modelica.Units.SI.Area AWin = 889.36;
    parameter Modelica.Units.SI.Area ATransparent = 889.36;


    // (B)窗
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
    "Buildings 示例常用取值";
    parameter Real gWin = 0.379;
    parameter Modelica.Units.SI.ThermalResistance RWin = 4.16e-4;
    parameter Real ratioWinConRad = 0.09
    "Buildings 示例常用取值";

    // (C)外护栏结构
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
    "Buildings 示例常用取值";
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
    "Buildings 示例常用取值";
    parameter Modelica.Units.SI.Area AExt = 2398.2;
    parameter Modelica.Units.SI.ThermalResistance RExt = 3.609e-4;
    parameter Modelica.Units.SI.ThermalResistance RExtRem = 3.609e-5;
    parameter Modelica.Units.SI.HeatCapacity CExt = 1e9;

    // ---------------------- Coil参数设置 ----------------------

    // ---------------------- 空气回路参数设置 ----------------------
    parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
      "蒸发器空气侧额定质量流量";
    parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


    Buildings.Fluid.Sources.MassFlowSource_T WatSou(
      redeclare package Medium = MediumA,
      m_flow=mAir_flow_nominal,
      use_T_in=true,
      nPorts=1)
      annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,
              -100})));




    // ============================================================================
    // 蒸发侧空气回路
    // ============================================================================

    Buildings.Fluid.Sources.Boundary_pT AirSink(
      redeclare package Medium = MediumA,
      nPorts=1)
      annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


    // ============================================================================
    // 水回路
    // ============================================================================

    Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
      redeclare package Medium1 = MediumW,
      redeclare package Medium2 = MediumA,
      m1_flow_nominal=mHeaPum_flow_nominal,
      m2_flow_nominal=mAir_flow_nominal,
      show_T=true,
      QCon_flow_nominal=QHea_flow_nominal,
      dTEva_nominal=dTEva_nominal,
      dTCon_nominal=dTCon_nominal,
      dp1_nominal=2000,
      dp2_nominal=200)
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={10,
              -80})));

    Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
      redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
      T_start=TIni)
      annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

    Buildings.Fluid.Storage.ExpansionVessel expVes(
      redeclare package Medium = MediumW,
      V_start=0.05,
      p_start=300000,
      T_start=TIni)
      annotation (Placement(
            transformation(
            extent={{-7,-7},{7,7}},
            rotation=-90,
            origin={77,-55})));

    Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
      redeclare package Medium = MediumW,
      T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
      annotation (Placement(
          transformation(
          extent={{-8,-8},{8,8}},
          rotation=90,
          origin={68,-10})));


    Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
      redeclare package Medium1 = MediumA,
      redeclare package Medium2 = MediumW,
      m1_flow_nominal=mSup_flow_nominal,
      m2_flow_nominal=mHeaPum_flow_nominal,
      dp1_nominal=200,
      dp2_nominal=3000,
      UA_nominal=UA_nominal*0.4)
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

    Buildings.Fluid.FixedResistances.PressureDrop res(
      redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
      dp_nominal=2000)
      annotation (Placement(
            transformation(
            extent={{7,-7},{-7,7}},
            rotation=90,
            origin={-45,-9})));

    Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
      redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
      T_start=TIni)
      annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-35,-73})));

    // ============================================================================
    // 空气回路
    // ============================================================================

    Buildings.Fluid.Sources.Boundary_pT AmbBou(
      redeclare package Medium = MediumA,
      use_T_in=true,
      nPorts=2)
      annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-134,62})));

    Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
      redeclare package Medium = MediumA,
      mOut_flow_nominal=mSup_flow_nominal,
      dpDamOut_nominal=50,
      dpFixOut_nominal=20,
      mRec_flow_nominal=mSup_flow_nominal,
      dpDamRec_nominal=50,
      dpFixRec_nominal=20,
      mExh_flow_nominal=mSup_flow_nominal,
      dpDamExh_nominal=50,
      dpFixExh_nominal=20)
      annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-73,
              59})));

    Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
      dp_nominal=800)
      annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

    Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
      annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

    Buildings.Fluid.FixedResistances.PressureDrop res1(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
      dp_nominal=300)
      annotation (Placement(
            transformation(
            extent={{-7,-7},{7,7}},
            rotation=90,
            origin={115,61})));
    Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
      redeclare package Medium = MediumA,
      VAir=VAir,
      nOrientations=1,
      AWin={AWin},
      ATransparent={ATransparent},
      hConWin=hConWin,
      RWin=RWin,
      gWin=gWin,
      ratioWinConRad=ratioWinConRad,
      indoorPortWin=false,
      nExt=1,
      AExt={AExt},
      hConExt=hConExt,
      hRad=hRad,
      RExt={RExt},
      RExtRem=RExtRem,
      CExt={CExt},
      indoorPortExtWalls=false,
      use_moisture_balance=false,
      use_C_flow=false,
      nPorts=2)
      annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={90,
              112})));


    Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
      annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

    Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
      annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

    Buildings.Fluid.FixedResistances.PressureDrop res2(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
      dp_nominal=300)
      annotation (Placement(
            transformation(
            extent={{-7,-7},{7,7}},
            rotation=180,
            origin={-27,81})));

    // ============================================================================
    // 数据读取
    // ============================================================================

    Modelica.Blocks.Sources.CombiTimeTable DataTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/DayData.mat",
      tableName     = "DayData",
      columns       = {2,3,4,5,6},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,
              150})));

    Modelica.Blocks.Sources.CombiTimeTable IntGains(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
      tableName     = "IntGains",
      columns={2,3},
      smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
      "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
      annotation (Placement(transformation(extent={{-124,140},{-104,160}})));

    Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
      annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={26,-31})));
    Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
      annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-16,-59})));
    Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
      annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={6,108})));
    Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
      annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-180,115})));
    Modelica.Blocks.Sources.Constant beta(k=0.4)
      annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-86,26})));
    Modelica.Blocks.Sources.Constant supflow(k=12) annotation (Placement(
          transformation(extent={{6,-6},{-6,6}}, origin={82,66})));
    Modelica.Blocks.Sources.Constant beta1(k=0)
      annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={46,186})));



    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
      annotation (Placement(transformation(extent={{152,104},{138,118}})));
    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
      annotation (Placement(transformation(extent={{152,118},{138,132}})));
    Modelica.Blocks.Sources.Constant mFlow(k=55)
      annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={32,-10})));
    Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
        Placement(transformation(extent={{-6,-7},{6,7}}, origin={28,129})));
  equation
    connect(TOut.y, WatSou.T_in);
    connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},{26,
            -100},{26,-86},{20,-86}},color={0,127,255}));
    connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{0,-86},{-26,
            -86},{-26,-100},{-30,-100}}, color={0,127,255}));
    connect(senHPIn.port_b, heaPum.port_a1)
      annotation (Line(points={{-28,-73},{-28,-74},{0,-74}}, color={0,127,255}));
    connect(senHPOut.port_a, heaPum.port_b1)
      annotation (Line(points={{34,-73},{34,-74},{20,-74}}, color={0,127,255}));
    connect(heaCoi.port_a2, WatPum.port_b)
      annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
    connect(heaCoi.port_b2, res.port_a)
      annotation (Line(points={{-10,28},{-45,28},{-45,-2}}, color={0,127,255}));
    connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-45,-16},{-46,-16},
            {-46,-73},{-42,-73}}, color={0,127,255}));
    connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-126,61.2},
            {-92,61.2},{-92,51.2},{-86,51.2}},
                                            color={0,127,255}));
    connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-60,51.2},{
            -14,51.2},{-14,40},{-10,40}}, color={0,127,255}));
    connect(heaCoi.port_b1, SupFan.port_a)
      annotation (Line(points={{10,40},{24,40},{24,42},{36,42}},
                                                 color={0,127,255}));
    connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{70,42},
            {70,43},{74,43}}, color={0,127,255}));
    connect(senSup.port_b, res1.port_a)
      annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
    connect(res1.port_b, Zone.ports[1]) annotation (Line(points={{115,68},{115,
            90},{104.237,90},{104.237,94.05}},
                                           color={0,127,255}));
    connect(senRet.port_a, Zone.ports[2]) annotation (Line(points={{54,79},{116,
            79},{116,90},{105.763,90},{105.763,94.05}},
                                                    color={0,127,255}));
    connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{26,79},
            {26,78},{22,78}}, color={0,127,255}));
    connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{-14,78},{
            -14,81},{-20,81}}, color={0,127,255}));
    connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-34,81},{-54,81},
            {-54,66.8},{-60,66.8}}, color={0,127,255}));
    connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-86,66.8},
            {-120,66.8},{-120,62.8},{-126,62.8}},
                                              color={0,127,255}));
    connect(TSup.y, heaPum.TSet) annotation (Line(points={{-9.4,-59},{-9.4,-60},{-2,
            -60},{-2,-71}}, color={0,0,127}));
    connect(TOut.y, preTem.T) annotation (Line(points={{-173.4,115},{-150,115},{-150,
            108},{-1.2,108}},
                        color={0,0,127}));
    connect(preTem.port, Zone.extWall)
      annotation (Line(points={{12,108},{66,108}}, color={191,0,0}));
    connect(preTem.port, Zone.window) annotation (Line(points={{12,108},{62,108},{
            62,116},{66,116}}, color={191,0,0}));
    connect(beta.y, MixBox.y) annotation (Line(points={{-79.4,26},{-73,26},{-73,43.4}},
          color={0,0,127}));
    connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-173.4,115},{-150,115},
            {-150,65.2},{-143.6,65.2}}, color={0,0,127}));
    connect(supflow.y, RetFan.m_flow_in) annotation (Line(points={{75.4,66},{32,66},
            {32,94},{14,94},{14,87.6}}, color={0,0,127}));
    connect(supflow.y, SupFan.m_flow_in)
      annotation (Line(points={{75.4,66},{44,66},{44,51.6}}, color={0,0,127}));
    connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},{48,
            -74},{70,-74},{70,-55}}, color={0,127,255}));
    connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{70,-36},
            {68,-36},{68,-18}}, color={0,127,255}));
    connect(IntGains.y[1], qIntConv.Q_flow);
    // 表输出 -> 热流源               // 对流 W
    connect(IntGains.y[2], qIntRad.Q_flow);   // 辐射 W
    connect(mFlow.y, WatPum.m_flow_in)
      annotation (Line(points={{38.6,-10},{58.4,-10}}, color={0,0,127}));
    connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{34.6,129},{62,129},{62,
            127},{65,127}}, color={0,0,127}));
    connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,125},
            {122,125},{122,120},{114,120}}, color={191,0,0}));
    connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},
            {120,111},{120,116},{114,116}}, color={191,0,0}));
    annotation (uses(Buildings(version="12.1.0")),
                experiment(StopTime=86400));
  end WithAHU;

  block SolarFromGHI_OneOrientation
    "Build RC.OneElement solar input (solRad) from GHI only using Buildings v12 components (start date by Y/M/D)."

    // ===================== Location (Weihai) =====================
    parameter Modelica.Units.SI.Angle lat(displayUnit="deg") =
        37.50*Modelica.Constants.pi/180 "Latitude [rad]";
    parameter Modelica.Units.SI.Angle lon(displayUnit="deg") =
        122.10*Modelica.Constants.pi/180 "Longitude [rad]";
    parameter Modelica.Units.SI.Time timZon(displayUnit="h") = 8*3600
      "Time zone offset [s] (UTC+8)";

    // ===================== Window orientation =====================
    parameter Modelica.Units.SI.Angle azi(displayUnit="deg") =
        Buildings.Types.Azimuth.S
      "Surface azimuth [rad] (S=0, E=-pi/2, W=+pi/2, N=pi)";
    parameter Modelica.Units.SI.Angle til(displayUnit="deg") =
        Buildings.Types.Tilt.Wall
      "Surface tilt [rad] (Wall=90deg)";

    // Window U-value used by transmission correction
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer UWin = 2.7
      "Whole-window U-value for CorrectionGDoublePane [W/(m2.K)]";

    // ===================== Data start date =====================
    parameter Integer year0(min=1900, max=2200) = 2025 "Start year (local time)";
    parameter Integer month0(min=1, max=12) = 1 "Start month (local time)";
    parameter Integer day0(min=1, max=31) = 10 "Start day (local time)";

    // ===================== Robustness settings =====================
    parameter Real cosZenMin = 0.05
      "Minimum cos(zenith) to compute DNI (avoid sunrise/sunset blow-up)";
    parameter Modelica.Units.SI.Irradiance HDirNorMax = 1200
      "Upper bound for DNI [W/m2]";

    // ===================== IO =====================
    Modelica.Blocks.Interfaces.RealInput HGloHor(unit="W/m2")
      "Global Horizontal Irradiance (GHI) [W/m2]"
      annotation (Placement(transformation(extent={{-140,-10},{-120,10}})));

    Modelica.Blocks.Interfaces.RealOutput solRad[1](unit="W/m2")
      "Transmitted solar radiation through window [W/m2] for RC.OneElement.solRad"
      annotation (Placement(transformation(extent={{120,-10},{140,10}})));

    // ---------- helper functions ----------
  protected
    function isLeapYear
      input Integer y;
      output Boolean leap;
    algorithm
      leap := (mod(y,4) == 0 and mod(y,100) <> 0) or (mod(y,400) == 0);
    end isLeapYear;

    function dayOfYear
      input Integer y;
      input Integer m;
      input Integer d;
      output Integer nDay;
    protected
      Integer cum[12];
    algorithm
      cum := {0,31,59,90,120,151,181,212,243,273,304,334};
      nDay := cum[m] + d;
      if (m > 2) and isLeapYear(y) then
        nDay := nDay + 1;
      end if;
    end dayOfYear;

    parameter Integer nDay0(min=1, max=366) = dayOfYear(year0, month0, day0)
      "Day-of-year computed from year0/month0/day0";

    // Expandable weather bus
    Buildings.BoundaryConditions.WeatherData.Bus weaBus
      annotation (Placement(transformation(extent={{-20,-10},{20,10}})));

    // Time handling
    Real tDay(unit="s") "Seconds in day";
    Integer nDayInt "Day of year (integer)";
    Real nDayR "Day of year (real)";
    Real cloTim(unit="s") "Seconds since start of year";

    // Solar time chain
    Buildings.BoundaryConditions.WeatherData.BaseClasses.LocalCivilTime locTim(
      final lon=lon,
      final timZon=timZon)
      annotation (Placement(transformation(extent={{-80,50},{-60,70}})));

    Buildings.BoundaryConditions.WeatherData.BaseClasses.EquationOfTime eqnTim
      annotation (Placement(transformation(extent={{-80,18},{-60,38}})));

    Buildings.BoundaryConditions.WeatherData.BaseClasses.SolarTime solTimCal
      annotation (Placement(transformation(extent={{-40,34},{-20,54}})));

    // Solar geometry
    Buildings.BoundaryConditions.SolarGeometry.BaseClasses.Declination decAng
      annotation (Placement(transformation(extent={{-10,58},{10,78}})));

    Buildings.BoundaryConditions.SolarGeometry.BaseClasses.SolarHourAngle solHouAng
      annotation (Placement(transformation(extent={{-10,34},{10,54}})));

    Buildings.BoundaryConditions.SolarGeometry.BaseClasses.ZenithAngle zen(final lat=lat)
      annotation (Placement(transformation(extent={{20,46},{40,66}})));

    // Irradiation on tilted surface
    Buildings.BoundaryConditions.SolarIrradiation.DirectTiltedSurface HDirTil(
      final til=til,
      final azi=azi)
      annotation (Placement(transformation(extent={{40,10},{60,30}})));

    Buildings.BoundaryConditions.SolarIrradiation.DiffusePerez HDifTil(
      final til=til,
      final azi=azi,
      final outSkyCon=true,
      final outGroCon=true)
      annotation (Placement(transformation(extent={{40,-20},{60,0}})));

    // Window transmission correction
    Buildings.ThermalZones.ReducedOrder.SolarGain.CorrectionGDoublePane corG(
      final UWin=UWin,
      final n=1)
      annotation (Placement(transformation(extent={{76,-10},{96,10}})));

    // Erbs variables
    Real cosZen;
    Real E0;
    Real I0n(unit="W/m2");
    Real I0h(unit="W/m2");
    Real Kt;
    Real Fd;
    Real HDifHor(unit="W/m2");
    Real HDirNor(unit="W/m2");
    Real HGloEff(unit="W/m2");

    function diffuseFractionErbs
      input Real Kt;
      output Real Fd;
    algorithm
      if Kt <= 0.22 then
        Fd := 1 - 0.09*Kt;
      elseif Kt <= 0.8 then
        Fd := 0.9511 - 0.1604*Kt + 4.388*Kt^2 - 16.638*Kt^3 + 12.336*Kt^4;
      else
        Fd := 0.165;
      end if;
    end diffuseFractionErbs;

  equation
    // ===================== Build time signals =====================
    tDay    = time - 86400*floor(time/86400);
    nDayInt = nDay0 + integer(floor(time/86400));
    nDayR   = nDayInt;
    cloTim  = (nDayR - 1.0)*86400 + tDay;

    // Populate minimal bus
    weaBus.cloTim = cloTim;
    weaBus.lat    = lat;

    // Solar time
    locTim.cloTim     = weaBus.cloTim;
    eqnTim.nDay       = nDayR;
    solTimCal.locTim  = locTim.locTim;
    solTimCal.equTim  = eqnTim.eqnTim;
    weaBus.solTim     = solTimCal.solTim;

    // Zenith / altitude
    decAng.nDay        = nDayR;
    solHouAng.solTim   = weaBus.solTim;
    zen.decAng         = decAng.decAng;
    zen.solHouAng      = solHouAng.solHouAng;

    weaBus.solZen = zen.zen;
    weaBus.alt    = (Modelica.Constants.pi/2) - zen.zen;

    cosZen = Modelica.Math.cos(zen.zen);

    // Effective GHI: enforce >=0 and 0 at night
    HGloEff = noEvent(if weaBus.alt <= 0 then 0.0 else max(0.0, HGloHor));

    // ===================== Erbs: GHI -> DHI + DNI =====================
    E0  = 1.0 + 0.033*Modelica.Math.cos(2*Modelica.Constants.pi*nDayR/365.0);
    I0n = 1367.0 * E0;
    I0h = I0n * max(0.0, cosZen);

    Kt = noEvent(if I0h > 1.0 then min(1.2, max(0.0, HGloEff/I0h)) else 0.0);
    Fd = noEvent(diffuseFractionErbs(Kt));

    // Diffuse horizontal: 0 at night
    HDifHor = noEvent(
      if weaBus.alt <= 0 then 0.0
      else max(0.0, min(HGloEff, Fd*HGloEff)));

    // Direct normal: robustly computed, 0 at night and near sunrise/sunset
    HDirNor = noEvent(
      if weaBus.alt <= 0 then 0.0
      else if cosZen > cosZenMin then
        min(HDirNorMax, max(0.0, (HGloEff - HDifHor)/cosZen))
      else 0.0);

    // Write to bus
    weaBus.HGloHor = HGloEff;
    weaBus.HDifHor = HDifHor;
    weaBus.HDirNor = HDirNor;

    // ===================== Tilted surface models =====================
    connect(weaBus, HDirTil.weaBus)
      annotation (Line(points={{0,0},{40,0},{40,20}}, color={255,204,51}));

    connect(weaBus, HDifTil.weaBus)
      annotation (Line(points={{0,0},{40,0},{40,-10}}, color={255,204,51}));

    // ===================== Transmission correction =====================
    connect(HDirTil.H, corG.HDirTil[1])
      annotation (Line(points={{61,20},{70,20},{70,6},{74,6}}, color={0,0,127}));

    connect(HDirTil.inc, corG.inc[1])
      annotation (Line(points={{61,16},{72,16},{72,-6},{74,-6}},
                                                               color={0,0,127}));

    connect(HDifTil.HSkyDifTil, corG.HSkyDifTil[1])
      annotation (Line(points={{61,-4},{72,-4},{72,2},{74,2}},   color={0,0,127}));

    connect(HDifTil.HGroDifTil, corG.HGroDifTil[1])
      annotation (Line(points={{61,-16},{70,-16},{70,-2},{74,-2}}, color={0,0,127}));

    solRad[1] = corG.solarRadWinTrans[1];

    annotation (
      uses(Buildings(version="12.1.0")),
      Icon(coordinateSystem(preserveAspectRatio=true, extent={{-100,-100},{100,100}}),
        graphics={
          Rectangle(extent={{-100,100},{100,-100}}, lineColor={0,0,0}),
          Text(extent={{-92,18},{92,-18}}, textString="GHI→SolRad", lineColor={0,0,0}),
          Text(extent={{-92,70},{92,40}}, textString="SolarFromGHI", lineColor={0,0,0})}),
      Diagram(coordinateSystem(preserveAspectRatio=true, extent={{-140,-100},{140,100}})));
  end SolarFromGHI_OneOrientation;

  model WithAHUTest

    replaceable package MediumA = Buildings.Media.Air;
    replaceable package MediumW = Buildings.Media.Water;


    // ============================================================================
    // 参数设置
    // ============================================================================


    parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
      "系统供回水初始温度";
    parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
      "系统室内初始温度";

    // ---------------------- 热泵额定工况 ----------------------
    parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
      "热泵冷凝器（供热侧）额定热流量";
    parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
      "冷凝器设计供回水温差（约 5 K）";
    parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
      "蒸发器设计进出水温差（约 5 K，符号为负）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
        QHea_flow_nominal/4200/dTCon_nominal
      "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
    parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
      "热泵水侧实际质量流量";
    parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
      "蒸发器空气侧额定质量流量";

    // ---------------------- 建筑参数设置 ----------------------
    // (A)几何
    parameter Modelica.Units.SI.Area AFlo = 10000;
    parameter Modelica.Units.SI.Volume VAir = 30000;

    parameter Modelica.Units.SI.Area AWin = 889.36;
    parameter Modelica.Units.SI.Area ATransparent = 889.36;


    // (B)窗
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
    "Buildings 示例常用取值";
    parameter Real gWin = 0.379;
    parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
    parameter Real ratioWinConRad = 0.09
    "Buildings 示例常用取值";

    // (C)外护栏结构
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
    "Buildings 示例常用取值";
    parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
    "Buildings 示例常用取值";
    parameter Modelica.Units.SI.Area AExt = 8000;
    parameter Modelica.Units.SI.ThermalResistance RExt = 5e-5;
    parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
    parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

    // ---------------------- Coil参数设置 ----------------------

    // ---------------------- 空气回路参数设置 ----------------------
    parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
      "空气回路额定质量流量";
    parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


    Buildings.Fluid.Sources.MassFlowSource_T WatSou(
      redeclare package Medium = MediumA,
      m_flow=mAir_flow_nominal,
      use_T_in=true,
      nPorts=1)
      annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,
              -100})));




    // ============================================================================
    // 蒸发侧空气回路
    // ============================================================================

    Buildings.Fluid.Sources.Boundary_pT AirSink(
      redeclare package Medium = MediumA,
      nPorts=1)
      annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


    // ============================================================================
    // 水回路
    // ============================================================================

    Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
      redeclare package Medium1 = MediumW,
      redeclare package Medium2 = MediumA,
      m1_flow_nominal=mHeaPum_flow_nominal,
      m2_flow_nominal=mAir_flow_nominal,
      show_T=true,
      QCon_flow_nominal=QHea_flow_nominal,
      dTEva_nominal=dTEva_nominal,
      dTCon_nominal=dTCon_nominal,
      use_eta_Carnot_nominal=false,
      COP_nominal=3,
      TCon_nominal=313.15,
      a={0.9,0.1,0},
      dp1_nominal=2000,
      dp2_nominal=200,
      TAppCon_nominal=5,
      TAppEva_nominal=5)
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={10,-78})));

    Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
      redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
      T_start=TIni)
      annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

    Buildings.Fluid.Storage.ExpansionVessel expVes(
      redeclare package Medium = MediumW,
      V_start=0.05,
      p_start=300000,
      T_start=TIni)
      annotation (Placement(
            transformation(
            extent={{-7,-7},{7,7}},
            rotation=-90,
            origin={77,-55})));

    Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
      redeclare package Medium = MediumW,
      T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
      annotation (Placement(
          transformation(
          extent={{-8,-8},{8,8}},
          rotation=90,
          origin={68,-10})));


    Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
      redeclare package Medium1 = MediumA,
      redeclare package Medium2 = MediumW,
      m1_flow_nominal=mSup_flow_nominal,
      m2_flow_nominal=mHeaPum_flow_nominal,
      dp1_nominal=200,
      dp2_nominal=3000,
      UA_nominal=3e4)
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

    Buildings.Fluid.FixedResistances.PressureDrop res(
      redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
      dp_nominal=2000)
      annotation (Placement(
            transformation(
            extent={{7,-7},{-7,7}},
            rotation=90,
            origin={-45,-9})));

    Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
      redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
      T_start=TIni)
      annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-35,-73})));

    // ============================================================================
    // 空气回路
    // ============================================================================

    Buildings.Fluid.Sources.Boundary_pT AmbBou(
      redeclare package Medium = MediumA,
      use_T_in=true,
      nPorts=2)
      annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-134,62})));

    Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
      redeclare package Medium = MediumA,
      mOut_flow_nominal=mSup_flow_nominal,
      dpDamOut_nominal=50,
      dpFixOut_nominal=20,
      mRec_flow_nominal=mSup_flow_nominal,
      dpDamRec_nominal=50,
      dpFixRec_nominal=20,
      mExh_flow_nominal=mSup_flow_nominal,
      dpDamExh_nominal=50,
      dpFixExh_nominal=20)
      annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-73,
              59})));

    Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
      dp_nominal=800)
      annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

    Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
      annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

    Buildings.Fluid.FixedResistances.PressureDrop res1(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
      dp_nominal=300)
      annotation (Placement(
            transformation(
            extent={{-7,-7},{7,7}},
            rotation=90,
            origin={115,61})));
    Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
      redeclare package Medium = MediumA,
      T_start=TRooIni,
      VAir=VAir,
      nOrientations=1,
      AWin={AWin},
      ATransparent={ATransparent},
      hConWin=hConWin,
      RWin=RWin,
      gWin=gWin,
      ratioWinConRad=ratioWinConRad,
      indoorPortWin=false,
      nExt=1,
      AExt={AExt},
      hConExt=hConExt,
      hRad=hRad,
      RExt={RExt},
      RExtRem=RExtRem,
      CExt={CExt},
      indoorPortExtWalls=false,
      use_moisture_balance=false,
      use_C_flow=false,
      nPorts=2)
      annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={90,
              112})));


    Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
      annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

    Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
      annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

    Buildings.Fluid.FixedResistances.PressureDrop res2(
      redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
      dp_nominal=300)
      annotation (Placement(
            transformation(
            extent={{-7,-7},{7,7}},
            rotation=180,
            origin={-27,81})));

    // ============================================================================
    // 数据读取
    // ============================================================================

    Modelica.Blocks.Sources.CombiTimeTable DataTab(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/DayData.mat",
      tableName     = "DayData",
      columns       = {2,3,4,5,6},
      smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
      "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
      annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,
              150})));

    Modelica.Blocks.Sources.CombiTimeTable IntGains(
      tableOnFile   = true,
      fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
      tableName     = "IntGains",
      columns={2,3},
      smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
      extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
      "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
      annotation (Placement(transformation(extent={{-124,140},{-104,160}})));

    Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
      annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={26,-31})));
    Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
      annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-16,-59})));
    Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
      annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={6,108})));
    Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
      annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-180,115})));
    Modelica.Blocks.Sources.Constant beta(k=0.3)
      annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-86,26})));
    Modelica.Blocks.Sources.Constant supflow(k=20) annotation (Placement(
          transformation(extent={{6,-6},{-6,6}}, origin={82,66})));



    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
      annotation (Placement(transformation(extent={{152,104},{138,118}})));
    Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
      annotation (Placement(transformation(extent={{152,118},{138,132}})));
    Modelica.Blocks.Sources.Constant mFlow(k=55)
      annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={32,-10})));
    Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
        Placement(transformation(extent={{-6,-7},{6,7}}, origin={28,129})));
  equation
    connect(TOut.y, WatSou.T_in);
    connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
            {26,-100},{26,-84},{20,-84}},
                                     color={0,127,255}));
    connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{0,-84},
            {-26,-84},{-26,-100},{-30,-100}},
                                         color={0,127,255}));
    connect(senHPIn.port_b, heaPum.port_a1)
      annotation (Line(points={{-28,-73},{-28,-72},{0,-72}}, color={0,127,255}));
    connect(senHPOut.port_a, heaPum.port_b1)
      annotation (Line(points={{34,-73},{34,-72},{20,-72}}, color={0,127,255}));
    connect(heaCoi.port_a2, WatPum.port_b)
      annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
    connect(heaCoi.port_b2, res.port_a)
      annotation (Line(points={{-10,28},{-45,28},{-45,-2}}, color={0,127,255}));
    connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-45,-16},{-46,-16},
            {-46,-73},{-42,-73}}, color={0,127,255}));
    connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-126,61.2},
            {-92,61.2},{-92,51.2},{-86,51.2}},
                                            color={0,127,255}));
    connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-60,51.2},{
            -14,51.2},{-14,40},{-10,40}}, color={0,127,255}));
    connect(heaCoi.port_b1, SupFan.port_a)
      annotation (Line(points={{10,40},{24,40},{24,42},{36,42}},
                                                 color={0,127,255}));
    connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{70,42},
            {70,43},{74,43}}, color={0,127,255}));
    connect(senSup.port_b, res1.port_a)
      annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
    connect(res1.port_b, Zone.ports[1]) annotation (Line(points={{115,68},{115,
            90},{104.237,90},{104.237,94.05}},
                                           color={0,127,255}));
    connect(senRet.port_a, Zone.ports[2]) annotation (Line(points={{54,79},{116,
            79},{116,90},{105.763,90},{105.763,94.05}},
                                                    color={0,127,255}));
    connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{26,79},
            {26,78},{22,78}}, color={0,127,255}));
    connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{-14,78},{
            -14,81},{-20,81}}, color={0,127,255}));
    connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-34,81},{-54,81},
            {-54,66.8},{-60,66.8}}, color={0,127,255}));
    connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-86,66.8},
            {-120,66.8},{-120,62.8},{-126,62.8}},
                                              color={0,127,255}));
    connect(TSup.y, heaPum.TSet) annotation (Line(points={{-9.4,-59},{-9.4,-60},
            {-2,-60},{-2,-69}},
                            color={0,0,127}));
    connect(TOut.y, preTem.T) annotation (Line(points={{-173.4,115},{-150,115},{-150,
            108},{-1.2,108}},
                        color={0,0,127}));
    connect(preTem.port, Zone.extWall)
      annotation (Line(points={{12,108},{66,108}}, color={191,0,0}));
    connect(preTem.port, Zone.window) annotation (Line(points={{12,108},{62,108},{
            62,116},{66,116}}, color={191,0,0}));
    connect(beta.y, MixBox.y) annotation (Line(points={{-79.4,26},{-73,26},{-73,43.4}},
          color={0,0,127}));
    connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-173.4,115},{-150,115},
            {-150,65.2},{-143.6,65.2}}, color={0,0,127}));
    connect(supflow.y, RetFan.m_flow_in) annotation (Line(points={{75.4,66},{32,66},
            {32,94},{14,94},{14,87.6}}, color={0,0,127}));
    connect(supflow.y, SupFan.m_flow_in)
      annotation (Line(points={{75.4,66},{44,66},{44,51.6}}, color={0,0,127}));
    connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},{48,
            -74},{70,-74},{70,-55}}, color={0,127,255}));
    connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{70,-36},
            {68,-36},{68,-18}}, color={0,127,255}));

    connect(mFlow.y, WatPum.m_flow_in)
      annotation (Line(points={{38.6,-10},{58.4,-10}}, color={0,0,127}));
    connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,125},{122,
            125},{122,120},{114,120}}, color={191,0,0}));
    connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},{
            120,111},{120,116},{114,116}}, color={191,0,0}));
    connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{34.6,129},{60,129},{60,
            127},{65,127}}, color={0,0,127}));
    connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-103,150},
            {158,150},{158,125},{152,125}}, color={0,0,127}));
    connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-103,150},
            {158,150},{158,111},{152,111}}, color={0,0,127}));
    annotation (uses(Buildings(version="12.1.0")),
                experiment(StopTime=86400));
  end WithAHUTest;

  package AHU_datareverse
    model WithAHUTest2Days

      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;


      // ============================================================================
      // 参数设置
      // ============================================================================


      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;


      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
      "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
      "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 5e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,
                -100})));




      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0.9,0.1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={10,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));


      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=3e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-45,-9})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-35,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-134,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-73,
                59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));
      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={90,
                112})));


      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-27,81})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20250110-20250111/processed_data/20250110-20250111_2DayData.mat",
        tableName     = "DayData",
        columns       = {2,3,4,5,6},
        smoothness    = Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,
                150})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
        tableName     = "IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-124,140},{-104,160}})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={26,-31})));
      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-16,-59})));
      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={6,108})));
      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-180,115})));
      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-86,26})));
      Modelica.Blocks.Sources.Constant supflow(k=20) annotation (Placement(
            transformation(extent={{6,-6},{-6,6}}, origin={82,66})));
      Modelica.Blocks.Sources.Constant beta1(k=0)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={46,186})));



      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{152,104},{138,118}})));
      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{152,118},{138,132}})));
      Modelica.Blocks.Sources.Constant mFlow(k=55)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={32,-10})));
      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
          Placement(transformation(extent={{-6,-7},{6,7}}, origin={28,129})));
    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {26,-100},{26,-84},{20,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{0,-84},
              {-26,-84},{-26,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-28,-73},{-28,-72},{0,-72}}, color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-72},{20,-72}}, color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-45,28},{-45,-2}}, color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-45,-16},{-46,-16},
              {-46,-73},{-42,-73}}, color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-126,61.2},
              {-92,61.2},{-92,51.2},{-86,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-60,51.2},{
              -14,51.2},{-14,40},{-10,40}}, color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{24,40},{24,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{70,42},
              {70,43},{74,43}}, color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(res1.port_b, Zone.ports[1]) annotation (Line(points={{115,68},{
              115,90},{104.237,90},{104.237,94.05}},
                                             color={0,127,255}));
      connect(senRet.port_a, Zone.ports[2]) annotation (Line(points={{54,79},{
              116,79},{116,90},{105.763,90},{105.763,94.05}},
                                                      color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{26,79},
              {26,78},{22,78}}, color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{-14,78},{
              -14,81},{-20,81}}, color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-34,81},{-54,81},
              {-54,66.8},{-60,66.8}}, color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-86,66.8},
              {-120,66.8},{-120,62.8},{-126,62.8}},
                                                color={0,127,255}));
      connect(TSup.y, heaPum.TSet) annotation (Line(points={{-9.4,-59},{-9.4,-60},
              {-2,-60},{-2,-69}},
                              color={0,0,127}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-173.4,115},{-150,115},{-150,
              108},{-1.2,108}},
                          color={0,0,127}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{12,108},{66,108}}, color={191,0,0}));
      connect(preTem.port, Zone.window) annotation (Line(points={{12,108},{62,108},{
              62,116},{66,116}}, color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-79.4,26},{-73,26},{-73,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-173.4,115},{-150,115},
              {-150,65.2},{-143.6,65.2}}, color={0,0,127}));
      connect(supflow.y, RetFan.m_flow_in) annotation (Line(points={{75.4,66},{32,66},
              {32,94},{14,94},{14,87.6}}, color={0,0,127}));
      connect(supflow.y, SupFan.m_flow_in)
        annotation (Line(points={{75.4,66},{44,66},{44,51.6}}, color={0,0,127}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},{48,
              -74},{70,-74},{70,-55}}, color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{70,-36},
              {68,-36},{68,-18}}, color={0,127,255}));

      connect(mFlow.y, WatPum.m_flow_in)
        annotation (Line(points={{38.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,125},{122,
              125},{122,120},{114,120}}, color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},{
              120,111},{120,116},{114,116}}, color={191,0,0}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{34.6,129},{60,129},{60,
              127},{65,127}}, color={0,0,127}));
      connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-103,150},
              {158,150},{158,125},{152,125}}, color={0,0,127}));
      connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-103,
              150},{158,150},{158,111},{152,111}}, color={0,0,127}));
      annotation (uses(Buildings(version="12.1.0")),
                  experiment(
          StopTime=172800,
          Interval=60,
          __Dymola_Algorithm="Dassl"));
    end WithAHUTest2Days;

    model WithAHUTest4Days

      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;


      // ============================================================================
      // 参数设置
      // ============================================================================


      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;


      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
      "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
      "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 5e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,-100})));




      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0,1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));


      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=3e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-41,-7})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-29,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-92,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-53,59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));
      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={92,104})));


      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-19,77})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20250112-20250115/processed_data/20250112-20250115_4DayData.mat",
        tableName     = "DayData",
        columns       = {2,3,4,5,6},
        smoothness=Modelica.Blocks.Types.Smoothness.LinearSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,132})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
        tableName     = "IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-110,132})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={38,-11})));
      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-24,-53})));
      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-5,-5},{5,5}}, origin={25,105})));
      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-154,105})));
      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-74,28},
            rotation=0)));

      Modelica.Blocks.Sources.Constant supflow(k=15) annotation (Placement(
            transformation(extent={{6,-6},{-6,6}}, origin={82,66})));



      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,111})));
      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,123})));
      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
          Placement(transformation(extent={{-6,-7},{6,7}}, origin={30,119})));
      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{-72,-100},{-60,-88}})));
    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {16,-100},{16,-84},{10,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{-10,-84},
              {-12,-84},{-12,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-22,-73},{-22,-72},{-10,-72}},
                                                               color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-74},{14,-74},{14,-72},{10,-72}},
                                                              color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-41,28},{-41,0}},  color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-41,-14},{
              -42,-14},{-42,-73},{-36,-73}},
                                    color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-84,
              61.2},{-70,61.2},{-70,51.2},{-66,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-40,
              51.2},{-16,51.2},{-16,40},{-10,40}},
                                            color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{30,40},{30,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{
              68,42},{68,43},{74,43}},
                                color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{
              28,79},{28,78},{22,78}},
                                color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{4,77},
              {-12,77}},         color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-26,77},{
              -36,77},{-36,66.8},{-40,66.8}},
                                      color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-66,
              66.8},{-80,66.8},{-80,62.8},{-84,62.8}},
                                                color={0,127,255}));
      connect(TSup.y, heaPum.TSet) annotation (Line(points={{-17.4,-53},{-17.4,
              -69},{-12,-69}},color={0,0,127}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-147.4,105},{19,105}},
                          color={238,46,47}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{30,105},{50,105},{50,100},{68,100}},
                                                     color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-67.4,28},{-53,28},{
              -53,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-147.4,105},{-108,
              105},{-108,65.2},{-101.6,65.2}},
                                          color={238,46,47}));
      connect(supflow.y, RetFan.m_flow_in) annotation (Line(points={{75.4,66},{
              32,66},{32,94},{14,94},{14,87.6}},
                                          color={0,0,127}));
      connect(supflow.y, SupFan.m_flow_in)
        annotation (Line(points={{75.4,66},{44,66},{44,51.6}}, color={0,0,127}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},
              {48,-74},{70,-74},{70,-55}},
                                       color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{
              70,-56},{68,-56},{68,-18}},
                                  color={0,127,255}));

      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,123},
              {120,123},{120,112},{116,112}},
                                         color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},
              {120,111},{120,108},{116,108}},color={191,0,0}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{36.6,119},{67,
              119}},          color={0,0,127}));
      connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,123},{152,123}}, color={0,0,127}));
      connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,111},{152,111}}, color={0,0,127}));
      connect(mDot.y, WatPum.m_flow_in) annotation (Line(points={{44.6,-11},{
              44.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(senRet.port_a, Zone.ports[1]) annotation (Line(points={{54,79},{
              106.237,79},{106.237,86.05}}, color={0,127,255}));
      connect(res1.port_b, Zone.ports[2]) annotation (Line(points={{115,68},{
              115,82},{107.763,82},{107.763,86.05}}, color={0,127,255}));
      connect(preTem.port, Zone.window) annotation (Line(points={{30,105},{48,
              105},{48,106},{68,106},{68,108}}, color={191,0,0}));
      connect(senHPIn.T, to_degC.u) annotation (Line(points={{-29,-65.3},{-80,
              -65.3},{-80,-94},{-73.2,-94}}, color={0,0,127}));
      annotation (uses(Buildings(version="12.1.0")),
                  experiment(
          StopTime=345600,
          Interval=60,
          __Dymola_Algorithm="Dassl"),
        Diagram(coordinateSystem(extent={{-200,-120},{180,160}})),
        Icon(coordinateSystem(extent={{-200,-120},{180,160}})));
    end WithAHUTest4Days;

    model WithAHUTest4Days_Fan

      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;


      // ============================================================================
      // 参数设置
      // ============================================================================


      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;


      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
      "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
      "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 5e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,
                -100})));




      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0.9,0.1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={10,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));


      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=3e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-45,-9})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-35,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-134,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-73,
                59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));
      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={90,
                112})));


      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-27,81})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20250112-20250115/processed_data/20250112-20250115_4DayData.mat",
        tableName     = "DayData",
        columns       = {2,3,4,5,6},
        smoothness=Modelica.Blocks.Types.Smoothness.LinearSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,
                150})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
        tableName     = "IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-124,140},{-104,160}})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={26,-31})));
      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-16,-59})));
      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={6,108})));
      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-180,115})));
      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-86,26})));
      Modelica.Blocks.Sources.Constant beta1(k=0)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={46,186})));



      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{152,104},{138,118}})));
      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{152,118},{138,132}})));
      Modelica.Blocks.Sources.Constant mFlow(k=55)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={32,-10})));
      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
          Placement(transformation(extent={{-6,-7},{6,7}}, origin={28,129})));
      Modelica.Blocks.Math.Gain gain(k=0.6)
        annotation (Placement(transformation(extent={{188,122},{176,134}})));
      Modelica.Blocks.Math.Gain gain1(k=0.6)
        annotation (Placement(transformation(extent={{190,98},{178,110}})));
      Modelica.Blocks.Sources.CombiTimeTable supFlowTab(
        tableOnFile=false,
        columns={2},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic,
        table=[
          0,     7.5;
          1800, 10;
          3600, 12.5;
          5400, 15;
          7200, 17.5;
          9000, 20;
          10800,22.5;
          12600,25;
          14400,27.5;
          16200,30;
          18000,27.5;
          19800,25;
          21600,22.5;
          23400,20;
          25200,17.5;
          27000,15;
          28800,12.5;
          30600,10;
          32400,7.5;
          86400,18.75])
        annotation (Placement(transformation(extent={{174,40},{154,60}})));
    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {26,-100},{26,-84},{20,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{0,-84},
              {-26,-84},{-26,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-28,-73},{-28,-72},{0,-72}}, color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-72},{20,-72}}, color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-45,28},{-45,-2}}, color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-45,-16},{-46,-16},
              {-46,-73},{-42,-73}}, color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-126,61.2},
              {-92,61.2},{-92,51.2},{-86,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-60,51.2},{
              -14,51.2},{-14,40},{-10,40}}, color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{24,40},{24,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{70,42},
              {70,43},{74,43}}, color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(res1.port_b, Zone.ports[1]) annotation (Line(points={{115,68},{
              115,90},{104.237,90},{104.237,94.05}},
                                             color={0,127,255}));
      connect(senRet.port_a, Zone.ports[2]) annotation (Line(points={{54,79},{
              116,79},{116,90},{105.763,90},{105.763,94.05}},
                                                      color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{26,79},
              {26,78},{22,78}}, color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{-14,78},{
              -14,81},{-20,81}}, color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-34,81},{-54,81},
              {-54,66.8},{-60,66.8}}, color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-86,66.8},
              {-120,66.8},{-120,62.8},{-126,62.8}},
                                                color={0,127,255}));
      connect(TSup.y, heaPum.TSet) annotation (Line(points={{-9.4,-59},{-9.4,-60},
              {-2,-60},{-2,-69}},
                              color={0,0,127}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-173.4,115},{-150,115},{-150,
              108},{-1.2,108}},
                          color={0,0,127}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{12,108},{66,108}}, color={191,0,0}));
      connect(preTem.port, Zone.window) annotation (Line(points={{12,108},{62,108},{
              62,116},{66,116}}, color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-79.4,26},{-73,26},{-73,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-173.4,115},{-150,115},
              {-150,65.2},{-143.6,65.2}}, color={0,0,127}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},{48,
              -74},{70,-74},{70,-55}}, color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{70,-36},
              {68,-36},{68,-18}}, color={0,127,255}));

      connect(mFlow.y, WatPum.m_flow_in)
        annotation (Line(points={{38.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,125},{122,
              125},{122,120},{114,120}}, color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},{
              120,111},{120,116},{114,116}}, color={191,0,0}));
      connect(gain.y, qIntRad.Q_flow) annotation (Line(points={{175.4,128},{158,128},
              {158,125},{152,125}}, color={0,0,127}));
      connect(gain1.y, qIntConv.Q_flow) annotation (Line(points={{177.4,104},{158,104},
              {158,111},{152,111}}, color={0,0,127}));
      connect(IntGains.y[2], gain.u) annotation (Line(points={{-103,150},{196,150},{
              196,128},{189.2,128}}, color={0,0,127}));
      connect(IntGains.y[1], gain1.u) annotation (Line(points={{-103,150},{196,150},
              {196,104},{191.2,104}}, color={0,0,127}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{34.6,129},{60,129},{60,
              127},{65,127}}, color={0,0,127}));
      connect(supFlowTab.y[1], SupFan.m_flow_in) annotation (Line(points={{153,
              50},{128,50},{128,48},{94,48},{94,56},{44,56},{44,51.6}}, color={
              0,0,127}));
      connect(supFlowTab.y[1], RetFan.m_flow_in) annotation (Line(points={{153,
              50},{128,50},{128,48},{94,48},{94,56},{30,56},{30,92},{14,92},{14,
              87.6}}, color={0,0,127}));
      annotation (uses(Buildings(version="12.1.0")),
                  experiment(
          StopTime=345600,
          Interval=60,
          __Dymola_Algorithm="Dassl"));
    end WithAHUTest4Days_Fan;

    model WithAHUTest4DaysFineTest
      "这个模型的效果更好，作为日后的基准模型，用的数据是20250112-20250115"


      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;


      // ============================================================================
      // 参数设置
      // ============================================================================


      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;


      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
      "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
      "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 1e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,-100})));




      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0.9,0.1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));


      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=9.5e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-41,-7})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-29,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-92,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-53,59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));
      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={92,104})));


      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-19,77})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20250112-20250115/processed_data/20250112-20250115_4DayData.mat",
        tableName     = "DayData",
        columns       = {2,3,4,5,6},
        smoothness=Modelica.Blocks.Types.Smoothness.MonotoneContinuousDerivative1,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,132})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
        tableName     = "IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-110,132})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={38,-11})));
      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-24,-53})));
      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-5,-5},{5,5}}, origin={25,105})));
      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-154,105})));
      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-74,28},
            rotation=0)));

      Modelica.Blocks.Sources.Constant supflow(k=15) annotation (Placement(
            transformation(extent={{6,-6},{-6,6}}, origin={80,66})));



      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,111})));
      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,123})));
      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
          Placement(transformation(extent={{-6,-7},{6,7}}, origin={30,119})));
      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{-62,-76},{-50,-64}})));
      Modelica.Blocks.Continuous.FirstOrder firstOrder(T=240, initType=Modelica.Blocks.Types.Init.InitialOutput)
        annotation (Placement(transformation(extent={{-8,-52},{12,-32}})));
    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {16,-100},{16,-84},{10,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{-10,-84},
              {-12,-84},{-12,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-22,-73},{-22,-72},{-10,-72}},
                                                               color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-74},{14,-74},{14,-72},{10,-72}},
                                                              color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-41,28},{-41,0}},  color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-41,-14},{
              -42,-14},{-42,-73},{-36,-73}},
                                    color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-84,
              61.2},{-70,61.2},{-70,51.2},{-66,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-40,
              51.2},{-16,51.2},{-16,40},{-10,40}},
                                            color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{30,40},{30,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{
              68,42},{68,43},{74,43}},
                                color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{
              28,79},{28,78},{22,78}},
                                color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{4,77},
              {-12,77}},         color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-26,77},{
              -36,77},{-36,66.8},{-40,66.8}},
                                      color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-66,
              66.8},{-80,66.8},{-80,62.8},{-84,62.8}},
                                                color={0,127,255}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-147.4,105},{19,105}},
                          color={238,46,47}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{30,105},{50,105},{50,100},{68,100}},
                                                     color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-67.4,28},{-53,28},{
              -53,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-147.4,105},{-108,
              105},{-108,65.2},{-101.6,65.2}},
                                          color={238,46,47}));
      connect(supflow.y, RetFan.m_flow_in) annotation (Line(points={{73.4,66},{
              32,66},{32,94},{14,94},{14,87.6}},
                                          color={0,0,127}));
      connect(supflow.y, SupFan.m_flow_in)
        annotation (Line(points={{73.4,66},{44,66},{44,51.6}}, color={0,0,127}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},
              {48,-74},{70,-74},{70,-55}},
                                       color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{
              70,-56},{68,-56},{68,-18}},
                                  color={0,127,255}));

      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,123},
              {120,123},{120,112},{116,112}},
                                         color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},
              {120,111},{120,108},{116,108}},color={191,0,0}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{36.6,119},{67,
              119}},          color={0,0,127}));
      connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,123},{152,123}}, color={0,0,127}));
      connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,111},{152,111}}, color={0,0,127}));
      connect(mDot.y, WatPum.m_flow_in) annotation (Line(points={{44.6,-11},{
              44.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(senRet.port_a, Zone.ports[1]) annotation (Line(points={{54,79},{
              106.237,79},{106.237,86.05}}, color={0,127,255}));
      connect(res1.port_b, Zone.ports[2]) annotation (Line(points={{115,68},{
              115,82},{107.763,82},{107.763,86.05}}, color={0,127,255}));
      connect(preTem.port, Zone.window) annotation (Line(points={{30,105},{48,
              105},{48,106},{68,106},{68,108}}, color={191,0,0}));
      connect(senHPIn.T, to_degC.u) annotation (Line(points={{-29,-65.3},{-46,-65.3},
              {-46,-60},{-70,-60},{-70,-70},{-63.2,-70}}, color={0,0,127}));
      connect(TSup.y, firstOrder.u) annotation (Line(points={{-17.4,-53},{-17.4,
              -26},{-10,-26},{-10,-42}}, color={0,0,127}));
      connect(firstOrder.y, heaPum.TSet) annotation (Line(points={{13,-42},{18,
              -42},{18,-62},{-12,-62},{-12,-69}}, color={0,0,127}));
      annotation (uses(Buildings(version="12.1.0")),
                  experiment(
          StopTime=345600,
          Interval=3600,
          __Dymola_Algorithm="Dassl"),
        Diagram(coordinateSystem(extent={{-200,-120},{180,160}})),
        Icon(coordinateSystem(extent={{-200,-120},{180,160}})));
    end WithAHUTest4DaysFineTest;

    model WithAHUTest4DaysFineTest_Fan


      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;


      // ============================================================================
      // 参数设置
      // ============================================================================


      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;


      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
      "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
      "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 1e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,-100})));




      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0.9,0.1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));


      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=9.5e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-41,-7})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-29,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-92,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-53,59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));
      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={92,104})));


      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-19,77})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20250112-20250115/processed_data/20250112-20250115_4DayData.mat",
        tableName     = "DayData",
        columns       = {2,3,4,5,6},
        smoothness=Modelica.Blocks.Types.Smoothness.LinearSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,132})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
        tableName     = "IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-110,132})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={38,-11})));
      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-24,-53})));
      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-5,-5},{5,5}}, origin={25,105})));
      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-154,105})));
      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-74,28},
            rotation=0)));



      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,111})));
      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,123})));
      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
          Placement(transformation(extent={{-6,-7},{6,7}}, origin={30,119})));
      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{-62,-76},{-50,-64}})));

      Modelica.Blocks.Sources.CombiTimeTable supFlowTab(
        tableOnFile=false,
        columns={2},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic,
        table=[
          0,     7.5;
          1800, 10;
          3600, 12.5;
          5400, 15;
          7200, 17.5;
          9000, 20;
          10800,22.5;
          12600,25;
          14400,27.5;
          16200,30;
          18000,27.5;
          19800,25;
          21600,22.5;
          23400,20;
          25200,17.5;
          27000,15;
          28800,12.5;
          30600,10;
          32400,7.5;
          86400,18.75])
        annotation (Placement(transformation(extent={{174,40},{154,60}})));
    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {16,-100},{16,-84},{10,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{-10,-84},
              {-12,-84},{-12,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-22,-73},{-22,-72},{-10,-72}},
                                                               color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-74},{14,-74},{14,-72},{10,-72}},
                                                              color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-41,28},{-41,0}},  color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-41,-14},{
              -42,-14},{-42,-73},{-36,-73}},
                                    color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-84,
              61.2},{-70,61.2},{-70,51.2},{-66,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-40,
              51.2},{-16,51.2},{-16,40},{-10,40}},
                                            color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{30,40},{30,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{
              68,42},{68,43},{74,43}},
                                color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{
              28,79},{28,78},{22,78}},
                                color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{4,77},
              {-12,77}},         color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-26,77},{
              -36,77},{-36,66.8},{-40,66.8}},
                                      color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-66,
              66.8},{-80,66.8},{-80,62.8},{-84,62.8}},
                                                color={0,127,255}));
      connect(TSup.y, heaPum.TSet) annotation (Line(points={{-17.4,-53},{-17.4,
              -69},{-12,-69}},color={0,0,127}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-147.4,105},{19,105}},
                          color={238,46,47}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{30,105},{50,105},{50,100},{68,100}},
                                                     color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-67.4,28},{-53,28},{
              -53,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-147.4,105},{-108,
              105},{-108,65.2},{-101.6,65.2}},
                                          color={238,46,47}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},
              {48,-74},{70,-74},{70,-55}},
                                       color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{
              70,-56},{68,-56},{68,-18}},
                                  color={0,127,255}));

      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,123},
              {120,123},{120,112},{116,112}},
                                         color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},
              {120,111},{120,108},{116,108}},color={191,0,0}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{36.6,119},{67,
              119}},          color={0,0,127}));
      connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,123},{152,123}}, color={0,0,127}));
      connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,111},{152,111}}, color={0,0,127}));
      connect(mDot.y, WatPum.m_flow_in) annotation (Line(points={{44.6,-11},{
              44.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(senRet.port_a, Zone.ports[1]) annotation (Line(points={{54,79},{
              106.237,79},{106.237,86.05}}, color={0,127,255}));
      connect(res1.port_b, Zone.ports[2]) annotation (Line(points={{115,68},{
              115,82},{107.763,82},{107.763,86.05}}, color={0,127,255}));
      connect(preTem.port, Zone.window) annotation (Line(points={{30,105},{48,
              105},{48,106},{68,106},{68,108}}, color={191,0,0}));
      connect(senHPIn.T, to_degC.u) annotation (Line(points={{-29,-65.3},{-46,-65.3},
              {-46,-60},{-70,-60},{-70,-70},{-63.2,-70}}, color={0,0,127}));
      connect(supFlowTab.y[1], RetFan.m_flow_in) annotation (Line(points={{153,
              50},{128,50},{128,76},{62,76},{62,92},{14,92},{14,87.6}}, color={
              0,0,127}));
      connect(supFlowTab.y[1], SupFan.m_flow_in) annotation (Line(points={{153,
              50},{128,50},{128,76},{62,76},{62,58},{44,58},{44,51.6}}, color={
              0,0,127}));
      annotation (uses(Buildings(version="12.1.0")),
                  experiment(
          StopTime=345600,
          Interval=60,
          __Dymola_Algorithm="Dassl"),
        Diagram(coordinateSystem(extent={{-200,-120},{180,160}})),
        Icon(coordinateSystem(extent={{-200,-120},{180,160}})));
    end WithAHUTest4DaysFineTest_Fan;

    model D20241225_20241228


      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;


      // ============================================================================
      // 参数设置
      // ============================================================================


      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;


      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
      "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
      "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 1e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,-100})));




      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0.9,0.1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));


      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=9.5e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-41,-7})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-29,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-92,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-53,59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));
      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={92,104})));


      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-19,77})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20241225-20241228/processed_data/20241225-20241228_4DayData.mat",
        tableName     = "DayData",
        columns       = {2,3,4,5,6},
        smoothness=Modelica.Blocks.Types.Smoothness.LinearSegments,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,132})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
        tableName     = "IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-110,132})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={38,-11})));
      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-24,-53})));
      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-5,-5},{5,5}}, origin={25,105})));
      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-154,105})));
      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-74,28},
            rotation=0)));

      Modelica.Blocks.Sources.Constant supflow(k=20) annotation (Placement(
            transformation(extent={{6,-6},{-6,6}}, origin={82,66})));



      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,111})));
      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,123})));
      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
          Placement(transformation(extent={{-6,-7},{6,7}}, origin={30,119})));
      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{-62,-76},{-50,-64}})));
      Modelica.Blocks.Continuous.FirstOrder firstOrder(T=240, initType=Modelica.Blocks.Types.Init.InitialOutput)
        annotation (Placement(transformation(extent={{-8,-52},{12,-32}})));
    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {16,-100},{16,-84},{10,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{-10,-84},
              {-12,-84},{-12,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-22,-73},{-22,-72},{-10,-72}},
                                                               color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-74},{14,-74},{14,-72},{10,-72}},
                                                              color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-41,28},{-41,0}},  color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-41,-14},{
              -42,-14},{-42,-73},{-36,-73}},
                                    color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-84,
              61.2},{-70,61.2},{-70,51.2},{-66,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-40,
              51.2},{-16,51.2},{-16,40},{-10,40}},
                                            color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{30,40},{30,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{
              68,42},{68,43},{74,43}},
                                color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{
              28,79},{28,78},{22,78}},
                                color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{4,77},
              {-12,77}},         color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-26,77},{
              -36,77},{-36,66.8},{-40,66.8}},
                                      color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-66,
              66.8},{-80,66.8},{-80,62.8},{-84,62.8}},
                                                color={0,127,255}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-147.4,105},{19,105}},
                          color={238,46,47}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{30,105},{50,105},{50,100},{68,100}},
                                                     color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-67.4,28},{-53,28},{
              -53,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-147.4,105},{-108,
              105},{-108,65.2},{-101.6,65.2}},
                                          color={238,46,47}));
      connect(supflow.y, RetFan.m_flow_in) annotation (Line(points={{75.4,66},{
              32,66},{32,94},{14,94},{14,87.6}},
                                          color={0,0,127}));
      connect(supflow.y, SupFan.m_flow_in)
        annotation (Line(points={{75.4,66},{44,66},{44,51.6}}, color={0,0,127}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},
              {48,-74},{70,-74},{70,-55}},
                                       color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{
              70,-56},{68,-56},{68,-18}},
                                  color={0,127,255}));

      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,123},
              {120,123},{120,112},{116,112}},
                                         color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},
              {120,111},{120,108},{116,108}},color={191,0,0}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{36.6,119},{67,
              119}},          color={0,0,127}));
      connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,123},{152,123}}, color={0,0,127}));
      connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,111},{152,111}}, color={0,0,127}));
      connect(mDot.y, WatPum.m_flow_in) annotation (Line(points={{44.6,-11},{
              44.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(senRet.port_a, Zone.ports[1]) annotation (Line(points={{54,79},{
              106.237,79},{106.237,86.05}}, color={0,127,255}));
      connect(res1.port_b, Zone.ports[2]) annotation (Line(points={{115,68},{
              115,82},{107.763,82},{107.763,86.05}}, color={0,127,255}));
      connect(preTem.port, Zone.window) annotation (Line(points={{30,105},{48,
              105},{48,106},{68,106},{68,108}}, color={191,0,0}));
      connect(senHPIn.T, to_degC.u) annotation (Line(points={{-29,-65.3},{-46,-65.3},
              {-46,-60},{-70,-60},{-70,-70},{-63.2,-70}}, color={0,0,127}));
      connect(TSup.y, firstOrder.u) annotation (Line(points={{-17.4,-53},{-17.4,
              -26},{-10,-26},{-10,-42}}, color={0,0,127}));
      connect(firstOrder.y, heaPum.TSet) annotation (Line(points={{13,-42},{18,
              -42},{18,-62},{-12,-62},{-12,-69}}, color={0,0,127}));
      annotation (uses(Buildings(version="12.1.0")),
                  experiment(
          StopTime=345600,
          Interval=60,
          __Dymola_Algorithm="Dassl"),
        Diagram(coordinateSystem(extent={{-200,-120},{180,160}})),
        Icon(coordinateSystem(extent={{-200,-120},{180,160}})));
    end D20241225_20241228;

    model WithAHUTest4DaysFineTest_for_plot
      "这个模型的效果更好，作为日后的基准模型，用的数据是20250112-20250115"


      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;


      // ============================================================================
      // 参数设置
      // ============================================================================


      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;


      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
      "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
      "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 1e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,-100})));




      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0.9,0.1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));


      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=9.5e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-41,-7})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-29,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-92,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-53,59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));
      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={92,104})));


      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-19,77})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20250112-20250115/processed_data/20250112-20250115_4DayData.mat",
        tableName     = "DayData",
        columns       = {2,3,4,5,6},
        smoothness=Modelica.Blocks.Types.Smoothness.MonotoneContinuousDerivative1,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,132})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
        tableName     = "IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-110,132})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={38,-11})));
      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-24,-53})));
      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-5,-5},{5,5}}, origin={25,105})));
      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-154,105})));
      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-74,28},
            rotation=0)));

      Modelica.Blocks.Sources.Constant supflow(k=5)
      annotation (Placement(
            transformation(extent={{6,-6},{-6,6}}, origin={172,22})));

      // ---------------------- Supply/Return air mass flow schedule ----------------------
      parameter Real mLev[:] = {5, 7.5, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30}
        "Air mass flow levels to sweep (kg/s)";

      parameter Real dwell = 900
        "Holding time per level (s)";

      // Build a periodic step table: [time, m] with ConstantSegments
      parameter Real mTable[:,2] = buildStepTable(mLev, dwell);

      Modelica.Blocks.Sources.CombiTimeTable mAirTab(
        table=mTable,
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        annotation (Placement(transformation(extent={{6,-6},{-6,6}}, origin={96,66})));



      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,111})));
      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,123})));
      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
          Placement(transformation(extent={{-6,-7},{6,7}}, origin={30,119})));
      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{-62,-76},{-50,-64}})));
      Modelica.Blocks.Continuous.FirstOrder firstOrder(T=240, initType=Modelica.Blocks.Types.Init.InitialOutput)
        annotation (Placement(transformation(extent={{-8,-52},{12,-32}})));

      function buildStepTable
        "Return a 2-column table [t, y] for CombiTimeTable (Periodic + ConstantSegments)"
        input Real yLev[:];
        input Real dwell "seconds per level";
        output Real tab[size(yLev,1)+1, 2];
      protected
        Integer n = size(yLev,1);
        Integer i;
      algorithm
        // Start point
        tab[1,1] := 0;
        tab[1,2] := yLev[1];

        // Each row is the time at which a new constant level begins
        for i in 2:n loop
          tab[i,1] := (i-1)*dwell;
          tab[i,2] := yLev[i];
        end for;

        // Last row defines the period end; value can repeat first level
        tab[n+1,1] := n*dwell;
        tab[n+1,2] := yLev[1];
      end buildStepTable;

    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {16,-100},{16,-84},{10,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{-10,-84},
              {-12,-84},{-12,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-22,-73},{-22,-72},{-10,-72}},
                                                               color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-74},{14,-74},{14,-72},{10,-72}},
                                                              color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-41,28},{-41,0}},  color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-41,-14},{
              -42,-14},{-42,-73},{-36,-73}},
                                    color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-84,
              61.2},{-70,61.2},{-70,51.2},{-66,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-40,
              51.2},{-16,51.2},{-16,40},{-10,40}},
                                            color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{30,40},{30,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{
              68,42},{68,43},{74,43}},
                                color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{
              28,79},{28,78},{22,78}},
                                color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{4,77},
              {-12,77}},         color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-26,77},{
              -36,77},{-36,66.8},{-40,66.8}},
                                      color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-66,
              66.8},{-80,66.8},{-80,62.8},{-84,62.8}},
                                                color={0,127,255}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-147.4,105},{19,105}},
                          color={238,46,47}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{30,105},{50,105},{50,100},{68,100}},
                                                     color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-67.4,28},{-53,28},{
              -53,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-147.4,105},{-108,
              105},{-108,65.2},{-101.6,65.2}},
                                          color={238,46,47}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},
              {48,-74},{70,-74},{70,-55}},
                                       color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{
              70,-56},{68,-56},{68,-18}},
                                  color={0,127,255}));

      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,123},
              {120,123},{120,112},{116,112}},
                                         color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},
              {120,111},{120,108},{116,108}},color={191,0,0}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{36.6,119},{67,
              119}},          color={0,0,127}));
      connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,123},{152,123}}, color={0,0,127}));
      connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,111},{152,111}}, color={0,0,127}));
      connect(mDot.y, WatPum.m_flow_in) annotation (Line(points={{44.6,-11},{
              44.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(senRet.port_a, Zone.ports[1]) annotation (Line(points={{54,79},{
              106.237,79},{106.237,86.05}}, color={0,127,255}));
      connect(res1.port_b, Zone.ports[2]) annotation (Line(points={{115,68},{
              115,82},{107.763,82},{107.763,86.05}}, color={0,127,255}));
      connect(preTem.port, Zone.window) annotation (Line(points={{30,105},{48,
              105},{48,106},{68,106},{68,108}}, color={191,0,0}));
      connect(senHPIn.T, to_degC.u) annotation (Line(points={{-29,-65.3},{-46,-65.3},
              {-46,-60},{-70,-60},{-70,-70},{-63.2,-70}}, color={0,0,127}));
      connect(TSup.y, firstOrder.u) annotation (Line(points={{-17.4,-53},{-17.4,
              -26},{-10,-26},{-10,-42}}, color={0,0,127}));
      connect(firstOrder.y, heaPum.TSet) annotation (Line(points={{13,-42},{18,
              -42},{18,-62},{-12,-62},{-12,-69}}, color={0,0,127}));
      connect(mAirTab.y[1], RetFan.m_flow_in) annotation (Line(points={{89.4,66},{32,
              66},{32,94},{14,94},{14,87.6}}, color={0,0,127}));
      connect(mAirTab.y[1], SupFan.m_flow_in)
        annotation (Line(points={{89.4,66},{44,66},{44,51.6}}, color={0,0,127}));
      annotation (uses(Buildings(version="12.1.0")),
                  experiment(
          StopTime=345600,
          Interval=60,
          __Dymola_Algorithm="Dassl"),
        Diagram(coordinateSystem(extent={{-200,-120},{180,160}})),
        Icon(coordinateSystem(extent={{-200,-120},{180,160}})));
    end WithAHUTest4DaysFineTest_for_plot;

    model D20250112_20250120
      "WithAHU4DaysFineTest作为基准模型，用的数据是20250112-20250120"


      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;


      // ============================================================================
      // 参数设置
      // ============================================================================


      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;


      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
      "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
      "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
      "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 1e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;


      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,-100})));




      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));


      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0.9,0.1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,                       m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));


      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=9.5e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-41,-7})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW, m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-29,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-92,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-53,59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));
      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={92,104})));


      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA, m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-19,77})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20250112-20250120/processed_data/20250112-20250120_9DayData.mat",
        tableName     = "DayData",
        columns       = {2,3,4,5,6},
        smoothness=Modelica.Blocks.Types.Smoothness.MonotoneContinuousDerivative1,
        extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,132})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile   = true,
        fileName      = "D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
        tableName     = "IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-110,132})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={38,-11})));
      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-24,-53})));
      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-5,-5},{5,5}}, origin={25,105})));
      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-154,105})));
      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-74,28},
            rotation=0)));

      Modelica.Blocks.Sources.Constant supflow(k=15) annotation (Placement(
            transformation(extent={{6,-6},{-6,6}}, origin={80,66})));



      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,111})));
      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={
                145,123})));
      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5]) annotation (
          Placement(transformation(extent={{-6,-7},{6,7}}, origin={30,119})));
      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{-62,-76},{-50,-64}})));
      Modelica.Blocks.Continuous.FirstOrder firstOrder(T=240, initType=Modelica.Blocks.Types.Init.InitialOutput)
        annotation (Placement(transformation(extent={{-8,-52},{12,-32}})));
    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {16,-100},{16,-84},{10,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{-10,-84},
              {-12,-84},{-12,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-22,-73},{-22,-72},{-10,-72}},
                                                               color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-74},{14,-74},{14,-72},{10,-72}},
                                                              color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}},  color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-41,28},{-41,0}},  color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-41,-14},{
              -42,-14},{-42,-73},{-36,-73}},
                                    color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-84,
              61.2},{-70,61.2},{-70,51.2},{-66,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-40,
              51.2},{-16,51.2},{-16,40},{-10,40}},
                                            color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{30,40},{30,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},{
              68,42},{68,43},{74,43}},
                                color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},{
              28,79},{28,78},{22,78}},
                                color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{4,77},
              {-12,77}},         color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-26,77},{
              -36,77},{-36,66.8},{-40,66.8}},
                                      color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-66,
              66.8},{-80,66.8},{-80,62.8},{-84,62.8}},
                                                color={0,127,255}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-147.4,105},{19,105}},
                          color={238,46,47}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{30,105},{50,105},{50,100},{68,100}},
                                                     color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-67.4,28},{-53,28},{
              -53,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-147.4,105},{-108,
              105},{-108,65.2},{-101.6,65.2}},
                                          color={238,46,47}));
      connect(supflow.y, RetFan.m_flow_in) annotation (Line(points={{73.4,66},{
              32,66},{32,94},{14,94},{14,87.6}},
                                          color={0,0,127}));
      connect(supflow.y, SupFan.m_flow_in)
        annotation (Line(points={{73.4,66},{44,66},{44,51.6}}, color={0,0,127}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},
              {48,-74},{70,-74},{70,-55}},
                                       color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},{
              70,-56},{68,-56},{68,-18}},
                                  color={0,127,255}));

      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,123},
              {120,123},{120,112},{116,112}},
                                         color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},
              {120,111},{120,108},{116,108}},color={191,0,0}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{36.6,119},{67,
              119}},          color={0,0,127}));
      connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,123},{152,123}}, color={0,0,127}));
      connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,111},{152,111}}, color={0,0,127}));
      connect(mDot.y, WatPum.m_flow_in) annotation (Line(points={{44.6,-11},{
              44.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(senRet.port_a, Zone.ports[1]) annotation (Line(points={{54,79},{
              106.237,79},{106.237,86.05}}, color={0,127,255}));
      connect(res1.port_b, Zone.ports[2]) annotation (Line(points={{115,68},{
              115,82},{107.763,82},{107.763,86.05}}, color={0,127,255}));
      connect(preTem.port, Zone.window) annotation (Line(points={{30,105},{48,
              105},{48,106},{68,106},{68,108}}, color={191,0,0}));
      connect(senHPIn.T, to_degC.u) annotation (Line(points={{-29,-65.3},{-46,-65.3},
              {-46,-60},{-70,-60},{-70,-70},{-63.2,-70}}, color={0,0,127}));
      connect(TSup.y, firstOrder.u) annotation (Line(points={{-17.4,-53},{-17.4,
              -26},{-10,-26},{-10,-42}}, color={0,0,127}));
      connect(firstOrder.y, heaPum.TSet) annotation (Line(points={{13,-42},{18,
              -42},{18,-62},{-12,-62},{-12,-69}}, color={0,0,127}));
      annotation (uses(Buildings(version="12.1.0")),
                  experiment(
          StopTime=781200,
          Interval=3600,
          __Dymola_Algorithm="Dassl"),
        Diagram(coordinateSystem(extent={{-200,-120},{180,160}})),
        Icon(coordinateSystem(extent={{-200,-120},{180,160}})));
    end D20250112_20250120;

    model D20241201_20250301
      "WithAHU4DaysFineTest作为基准模型，用的数据是20241201-20250301"

      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;

      // ============================================================================
      // 参数设置
      // ============================================================================

      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;

      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
        "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
        "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
        "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
        "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 1e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;

      // ---------------------- 新增：送风流量控制参数 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSupMin = 8
        "最小送风质量流量";
      parameter Modelica.Units.SI.MassFlowRate mSupMax = 16
        "最大送风质量流量";
      parameter Modelica.Units.SI.MassFlowRate mSupDay = 12.5
        "白天基础送风质量流量";
      parameter Modelica.Units.SI.MassFlowRate mSupNight = 11
        "夜间基础送风质量流量";
      parameter Modelica.Units.SI.MassFlowRate mSupAmp = 0.8
        "日内正弦扰动幅值";
      parameter Real kTSup = 1.0
        "室温偏差对送风流量修正增益 [kg/s/K]";

      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,-100})));

      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));

      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0.9,0.1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW,
        m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,
        m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));

      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=9.5e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW,
        m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-41,-7})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW,
        m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-29,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-92,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-53,59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));

      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={92,104})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-19,77})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile=true,
        fileName="D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20241201-20250301/processed_data/20241201-20250301_Data.mat",
        tableName="DayData",
        columns={2,3,4,5,6},
        smoothness=Modelica.Blocks.Types.Smoothness.MonotoneContinuousDerivative1,
        extrapolation=Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,132})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile=true,
        fileName="D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains_perturbed.mat",
        tableName="IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-110,132})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={38,-11})));

      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-24,-53})));

      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-5,-5},{5,5}}, origin={25,105})));

      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-154,105})));

      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-74,28},
            rotation=0)));

      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={145,111})));

      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={145,123})));

      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={30,119})));

      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{-62,-76},{-50,-64}})));

      Modelica.Blocks.Continuous.FirstOrder firstOrder(
        T=240,
        initType=Modelica.Blocks.Types.Init.InitialOutput)
        annotation (Placement(transformation(extent={{-8,-52},{12,-32}})));

      // ============================================================================
      // 新增：送风流量日内扰动控制
      // ============================================================================

      Modelica.Blocks.Sources.RealExpression TZoneC(y=Zone.TAir - 273.15)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={76,96})));

      Modelica.Blocks.Sources.RealExpression TSetRoom(
        y=if mod(time, 86400) >= 7*3600 and mod(time, 86400) < 22*3600 then 20 else 19.2)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={76,84})));

      Modelica.Blocks.Sources.RealExpression mSupBase(
        y=if mod(time, 86400) >= 7*3600 and mod(time, 86400) < 22*3600 then mSupDay else mSupNight)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={76,72})));

      Modelica.Blocks.Sources.RealExpression mSupSin(
        y=mSupAmp*sin(2*Modelica.Constants.pi*time/86400))
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={76,60})));

      Modelica.Blocks.Sources.RealExpression mSupCmdRaw(
        y=mSupBase.y + mSupSin.y - kTSup*(TZoneC.y - TSetRoom.y))
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={212,66})));

      Modelica.Blocks.Nonlinear.Limiter supFlowLimiter(
        uMax=mSupMax,
        uMin=mSupMin)
        annotation (Placement(transformation(extent={{194,60},{182,72}})));

      Modelica.Blocks.Continuous.FirstOrder supFlowFilter(
        T=300,
        initType=Modelica.Blocks.Types.Init.InitialOutput,
        y_start=14)
        annotation (Placement(transformation(extent={{166,80},{154,92}})));

    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {16,-100},{16,-84},{10,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{-10,-84},
              {-12,-84},{-12,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-22,-73},{-22,-72},{-10,-72}},
                                                               color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-74},{14,-74},{14,-72},{10,-72}},
                                                              color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}}, color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-41,28},{-41,0}}, color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-41,-14},
              {-42,-14},{-42,-73},{-36,-73}},
                                    color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-84,61.2},
              {-70,61.2},{-70,51.2},{-66,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-40,51.2},
              {-16,51.2},{-16,40},{-10,40}},color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{30,40},{30,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},
              {68,42},{68,43},{74,43}},
                                color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},
              {28,79},{28,78},{22,78}},
                                color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{4,77},
              {-12,77}}, color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-26,77},
              {-36,77},{-36,66.8},{-40,66.8}},
                                      color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-66,66.8},
              {-80,66.8},{-80,62.8},{-84,62.8}},color={0,127,255}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-147.4,105},{19,105}},
                          color={238,46,47}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{30,105},{50,105},{50,100},{68,100}},
                                                     color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-67.4,28},{-53,28},
              {-53,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-147.4,105},{-108,105},
              {-108,65.2},{-101.6,65.2}}, color={238,46,47}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},
              {48,-74},{70,-74},{70,-55}},
                                       color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},
              {70,-56},{68,-56},{68,-18}},
                                  color={0,127,255}));

      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,123},
              {120,123},{120,112},{116,112}},
                                         color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},
              {120,111},{120,108},{116,108}}, color={191,0,0}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{36.6,119},{67,119}},
              color={0,0,127}));
      connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,123},{152,123}}, color={0,0,127}));
      connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,111},{152,111}}, color={0,0,127}));
      connect(mDot.y, WatPum.m_flow_in) annotation (Line(points={{44.6,-11},
              {44.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(senRet.port_a, Zone.ports[1]) annotation (Line(points={{54,79},{
              106.237,79},{106.237,86.05}},  color={0,127,255}));
      connect(res1.port_b, Zone.ports[2]) annotation (Line(points={{115,68},{
              115,82},{107.763,82},{107.763,86.05}},
                                             color={0,127,255}));
      connect(preTem.port, Zone.window) annotation (Line(points={{30,105},{48,105},
              {48,106},{68,106},{68,108}}, color={191,0,0}));
      connect(senHPIn.T, to_degC.u) annotation (Line(points={{-29,-65.3},{-46,-65.3},
              {-46,-60},{-70,-60},{-70,-70},{-63.2,-70}}, color={0,0,127}));
      connect(TSup.y, firstOrder.u) annotation (Line(points={{-17.4,-53},{-17.4,-26},
              {-10,-26},{-10,-42}}, color={0,0,127}));
      connect(firstOrder.y, heaPum.TSet) annotation (Line(points={{13,-42},{18,-42},
              {18,-62},{-12,-62},{-12,-69}}, color={0,0,127}));

      // 新增：送风流量控制连接
      connect(mSupCmdRaw.y, supFlowLimiter.u) annotation (Line(points={{218.6,
              66},{222,66},{222,56},{200,56},{200,66},{195.2,66}},
                                          color={0,0,127}));
      connect(supFlowLimiter.y, supFlowFilter.u) annotation (Line(points={{181.4,
              66},{174,66},{174,86},{167.2,86}},
                           color={0,0,127}));
      connect(supFlowFilter.y, SupFan.m_flow_in) annotation (Line(points={{153.4,
              86},{130,86},{130,28},{70,28},{70,30},{62,30},{62,58},{44,58},{44,
              51.6}},                               color={0,0,127}));
      connect(supFlowFilter.y, RetFan.m_flow_in) annotation (Line(points={{153.4,
              86},{130,86},{130,28},{70,28},{70,30},{62,30},{62,92},{14,92},{14,
              87.6}},                               color={0,0,127}));

      annotation (
        uses(Buildings(version="12.1.0")),
        experiment(
          StopTime=7862400,
          Interval=900,
          __Dymola_Algorithm="Dassl"),
        Diagram(coordinateSystem(extent={{-200,-120},{180,160}})),
        Icon(coordinateSystem(extent={{-200,-120},{180,160}})));
    end D20241201_20250301;

    model D20250112_20250116
      "WithAHU4DaysFineTest作为基准模型，用的数据是20250112_20250116"

      replaceable package MediumA = Buildings.Media.Air;
      replaceable package MediumW = Buildings.Media.Water;

      // ============================================================================
      // 参数设置
      // ============================================================================

      parameter Modelica.Units.SI.Temperature TIni = 273.15 + 30
        "系统供回水初始温度";
      parameter Modelica.Units.SI.Temperature TRooIni = 273.15 + 15
        "系统室内初始温度";

      // ---------------------- 热泵额定工况 ----------------------
      parameter Modelica.Units.SI.HeatFlowRate QHea_flow_nominal = 450e3
        "热泵冷凝器（供热侧）额定热流量";
      parameter Modelica.Units.SI.TemperatureDifference dTCon_nominal = 2
        "冷凝器设计供回水温差（约 5 K）";
      parameter Modelica.Units.SI.TemperatureDifference dTEva_nominal = -5
        "蒸发器设计进出水温差（约 5 K，符号为负）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_nominal =
          QHea_flow_nominal/4200/dTCon_nominal
        "热泵水侧额定质量流量（按 Q = m·cp·ΔT 计算）";
      parameter Modelica.Units.SI.MassFlowRate mHeaPum_flow_real = 55
        "热泵水侧实际质量流量";
      parameter Modelica.Units.SI.MassFlowRate mAir_flow_nominal = 64
        "蒸发器空气侧额定质量流量";

      // ---------------------- 建筑参数设置 ----------------------
      // (A)几何
      parameter Modelica.Units.SI.Area AFlo = 10000;
      parameter Modelica.Units.SI.Volume VAir = 30000;

      parameter Modelica.Units.SI.Area AWin = 889.36;
      parameter Modelica.Units.SI.Area ATransparent = 889.36;

      // (B)窗
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConWin = 2.7
        "Buildings 示例常用取值";
      parameter Real gWin = 0.379;
      parameter Modelica.Units.SI.ThermalResistance RWin = 1e-4;
      parameter Real ratioWinConRad = 0.09
        "Buildings 示例常用取值";

      // (C)外护栏结构
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hConExt = 2.7
        "Buildings 示例常用取值";
      parameter Modelica.Units.SI.CoefficientOfHeatTransfer hRad = 5
        "Buildings 示例常用取值";
      parameter Modelica.Units.SI.Area AExt = 8000;
      parameter Modelica.Units.SI.ThermalResistance RExt = 1e-5;
      parameter Modelica.Units.SI.ThermalResistance RExtRem = 1e-5;
      parameter Modelica.Units.SI.HeatCapacity CExt = 9e7;

      // ---------------------- Coil参数设置 ----------------------

      // ---------------------- 空气回路参数设置 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSup_flow_nominal = 25
        "空气回路额定质量流量";
      parameter Modelica.Units.SI.ThermalConductance UA_nominal = 3.0e4;

      // ---------------------- 新增：送风流量控制参数 ----------------------
      parameter Modelica.Units.SI.MassFlowRate mSupMin = 8
        "最小送风质量流量";
      parameter Modelica.Units.SI.MassFlowRate mSupMax = 16
        "最大送风质量流量";
      parameter Modelica.Units.SI.MassFlowRate mSupDay = 12.5
        "白天基础送风质量流量";
      parameter Modelica.Units.SI.MassFlowRate mSupNight = 11
        "夜间基础送风质量流量";
      parameter Modelica.Units.SI.MassFlowRate mSupAmp = 0.8
        "日内正弦扰动幅值";
      parameter Real kTSup = 1.0
        "室温偏差对送风流量修正增益 [kg/s/K]";

      Buildings.Fluid.Sources.MassFlowSource_T WatSou(
        redeclare package Medium = MediumA,
        m_flow=mAir_flow_nominal,
        use_T_in=true,
        nPorts=1)
        annotation (Placement(transformation(extent={{10,-10},{-10,10}}, origin={58,-100})));

      // ============================================================================
      // 蒸发侧空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AirSink(
        redeclare package Medium = MediumA,
        nPorts=1)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-38,-100})));

      // ============================================================================
      // 水回路
      // ============================================================================

      Buildings.Fluid.HeatPumps.Carnot_TCon heaPum(
        redeclare package Medium1 = MediumW,
        redeclare package Medium2 = MediumA,
        m1_flow_nominal=mHeaPum_flow_nominal,
        m2_flow_nominal=mAir_flow_nominal,
        show_T=true,
        QCon_flow_nominal=QHea_flow_nominal,
        dTEva_nominal=dTEva_nominal,
        dTCon_nominal=dTCon_nominal,
        use_eta_Carnot_nominal=false,
        COP_nominal=3,
        TCon_nominal=313.15,
        a={0.9,0.1,0},
        dp1_nominal=2000,
        dp2_nominal=200,
        TAppCon_nominal=5,
        TAppEva_nominal=5)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,-78})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPOut(
        redeclare package Medium = MediumW,
        m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={41,-73})));

      Buildings.Fluid.Storage.ExpansionVessel expVes(
        redeclare package Medium = MediumW,
        V_start=0.05,
        p_start=300000,
        T_start=TIni)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=-90,
              origin={77,-55})));

      Buildings.Fluid.Movers.FlowControlled_m_flow WatPum(
        redeclare package Medium = MediumW,
        T_start=TIni,
        m_flow_nominal=mHeaPum_flow_nominal)
        annotation (Placement(
            transformation(
            extent={{-8,-8},{8,8}},
            rotation=90,
            origin={68,-10})));

      Buildings.Fluid.HeatExchangers.DryCoilCounterFlow heaCoi(
        redeclare package Medium1 = MediumA,
        redeclare package Medium2 = MediumW,
        m1_flow_nominal=mSup_flow_nominal,
        m2_flow_nominal=mHeaPum_flow_nominal,
        dp1_nominal=200,
        dp2_nominal=3000,
        UA_nominal=9.5e4)
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={0,34})));

      Buildings.Fluid.FixedResistances.PressureDrop res(
        redeclare package Medium = MediumW,
        m_flow_nominal=mHeaPum_flow_nominal,
        dp_nominal=2000)
        annotation (Placement(
              transformation(
              extent={{7,-7},{-7,7}},
              rotation=90,
              origin={-41,-7})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senHPIn(
        redeclare package Medium = MediumW,
        m_flow_nominal=mHeaPum_flow_nominal,
        T_start=TIni)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={-29,-73})));

      // ============================================================================
      // 空气回路
      // ============================================================================

      Buildings.Fluid.Sources.Boundary_pT AmbBou(
        redeclare package Medium = MediumA,
        use_T_in=true,
        nPorts=2)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={-92,62})));

      Buildings.Fluid.Actuators.Dampers.MixingBox MixBox(
        redeclare package Medium = MediumA,
        mOut_flow_nominal=mSup_flow_nominal,
        dpDamOut_nominal=50,
        dpFixOut_nominal=20,
        mRec_flow_nominal=mSup_flow_nominal,
        dpDamRec_nominal=50,
        dpFixRec_nominal=20,
        mExh_flow_nominal=mSup_flow_nominal,
        dpDamExh_nominal=50,
        dpFixExh_nominal=20)
        annotation (Placement(transformation(extent={{-13,13},{13,-13}}, origin={-53,59})));

      Buildings.Fluid.Movers.FlowControlled_m_flow SupFan(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{-8,-8},{8,8}}, origin={44,42})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senSup(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{-7,-7},{7,7}}, origin={81,43})));

      Buildings.Fluid.FixedResistances.PressureDrop res1(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=90,
              origin={115,61})));

      Buildings.ThermalZones.ReducedOrder.RC.OneElement Zone(
        redeclare package Medium = MediumA,
        T_start=TRooIni,
        VAir=VAir,
        nOrientations=1,
        AWin={AWin},
        ATransparent={ATransparent},
        hConWin=hConWin,
        RWin=RWin,
        gWin=gWin,
        ratioWinConRad=ratioWinConRad,
        indoorPortWin=false,
        nExt=1,
        AExt={AExt},
        hConExt=hConExt,
        hRad=hRad,
        RExt={RExt},
        RExtRem=RExtRem,
        CExt={CExt},
        indoorPortExtWalls=false,
        use_moisture_balance=false,
        use_C_flow=false,
        nPorts=2)
        annotation (Placement(transformation(extent={{-24,-18},{24,18}}, origin={92,104})));

      Buildings.Fluid.Sensors.TemperatureTwoPort senRet(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal)
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={47,79})));

      Buildings.Fluid.Movers.FlowControlled_m_flow RetFan(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal,
        dp_nominal=800)
        annotation (Placement(transformation(extent={{8,-8},{-8,8}}, origin={14,78})));

      Buildings.Fluid.FixedResistances.PressureDrop res2(
        redeclare package Medium = MediumA,
        m_flow_nominal=mSup_flow_nominal,
        dp_nominal=300)
        annotation (Placement(
              transformation(
              extent={{-7,-7},{7,7}},
              rotation=180,
              origin={-19,77})));

      // ============================================================================
      // 数据读取
      // ============================================================================

      Modelica.Blocks.Sources.CombiTimeTable DataTab(
        tableOnFile=true,
        fileName="D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/Project/data/20241201-20250301/processed_data/20241201-20250301_Data.mat",
        tableName="DayData",
        columns={2,3,4,5,6},
        smoothness=Modelica.Blocks.Types.Smoothness.MonotoneContinuousDerivative1,
        extrapolation=Modelica.Blocks.Types.Extrapolation.HoldLastPoint)
        "分钟级数据表,2:室外温度，℃，1；3：供水温度，℃，2；4：回水温度，℃，3；5：瞬时水流量，kg/s，4；6：室外辐照度，W/m2,5"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-150,132})));

      Modelica.Blocks.Sources.CombiTimeTable IntGains(
        tableOnFile=true,
        fileName="D:/LenovoSoftstore/Dymola/WorkingSpace/Resource/GuoHeV1/AHU/IntGains.mat",
        tableName="IntGains",
        columns={2,3},
        smoothness=Modelica.Blocks.Types.Smoothness.ConstantSegments,
        extrapolation=Modelica.Blocks.Types.Extrapolation.Periodic)
        "Occupant gains: y[1]=Qconv(W), y[2]=Qrad(W)"
        annotation (Placement(transformation(extent={{-10,-10},{10,10}}, origin={-110,132})));

      Modelica.Blocks.Sources.RealExpression mDot(y=DataTab.y[4])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={38,-11})));

      Modelica.Blocks.Sources.RealExpression TSup(y=DataTab.y[2] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-24,-53})));

      Buildings.HeatTransfer.Sources.PrescribedTemperature preTem
        annotation (Placement(transformation(extent={{-5,-5},{5,5}}, origin={25,105})));

      Modelica.Blocks.Sources.RealExpression TOut(y=DataTab.y[1] + 273.15)
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={-154,105})));

      Modelica.Blocks.Sources.Constant beta(k=0.3)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={-74,28},
            rotation=0)));

      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntConv
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={145,111})));

      Modelica.Thermal.HeatTransfer.Sources.PrescribedHeatFlow qIntRad
        annotation (Placement(transformation(extent={{7,-7},{-7,7}}, origin={145,123})));

      Modelica.Blocks.Sources.RealExpression Sol(y=DataTab.y[5])
        annotation (Placement(transformation(extent={{-6,-7},{6,7}}, origin={30,119})));

      Modelica.Blocks.Math.UnitConversions.To_degC to_degC
        annotation (Placement(transformation(extent={{-62,-76},{-50,-64}})));

      Modelica.Blocks.Continuous.FirstOrder firstOrder(
        T=240,
        initType=Modelica.Blocks.Types.Init.InitialOutput)
        annotation (Placement(transformation(extent={{-8,-52},{12,-32}})));

      // ============================================================================
      // 新增：送风流量日内扰动控制
      // ============================================================================

      Modelica.Blocks.Sources.RealExpression TZoneC(y=Zone.TAir - 273.15)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={76,96})));

      Modelica.Blocks.Sources.RealExpression TSetRoom(
        y=if mod(time, 86400) >= 7*3600 and mod(time, 86400) < 22*3600 then 20 else 19.2)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={76,84})));

      Modelica.Blocks.Sources.RealExpression mSupBase(
        y=if mod(time, 86400) >= 7*3600 and mod(time, 86400) < 22*3600 then mSupDay else mSupNight)
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={76,72})));

      Modelica.Blocks.Sources.RealExpression mSupSin(
        y=mSupAmp*sin(2*Modelica.Constants.pi*time/86400))
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={76,60})));

      Modelica.Blocks.Sources.RealExpression mSupCmdRaw(
        y=mSupBase.y + mSupSin.y - kTSup*(TZoneC.y - TSetRoom.y))
        annotation (Placement(transformation(extent={{-6,-6},{6,6}}, origin={212,66})));

      Modelica.Blocks.Nonlinear.Limiter supFlowLimiter(
        uMax=mSupMax,
        uMin=mSupMin)
        annotation (Placement(transformation(extent={{194,60},{182,72}})));

      Modelica.Blocks.Continuous.FirstOrder supFlowFilter(
        T=300,
        initType=Modelica.Blocks.Types.Init.InitialOutput,
        y_start=14)
        annotation (Placement(transformation(extent={{166,80},{154,92}})));

    equation
      connect(TOut.y, WatSou.T_in);
      connect(WatSou.ports[1], heaPum.port_a2) annotation (Line(points={{48,-100},
              {16,-100},{16,-84},{10,-84}},
                                       color={0,127,255}));
      connect(heaPum.port_b2, AirSink.ports[1]) annotation (Line(points={{-10,-84},
              {-12,-84},{-12,-100},{-30,-100}},
                                           color={0,127,255}));
      connect(senHPIn.port_b, heaPum.port_a1)
        annotation (Line(points={{-22,-73},{-22,-72},{-10,-72}},
                                                               color={0,127,255}));
      connect(senHPOut.port_a, heaPum.port_b1)
        annotation (Line(points={{34,-73},{34,-74},{14,-74},{14,-72},{10,-72}},
                                                              color={0,127,255}));
      connect(heaCoi.port_a2, WatPum.port_b)
        annotation (Line(points={{10,28},{68,28},{68,-2}}, color={0,127,255}));
      connect(heaCoi.port_b2, res.port_a)
        annotation (Line(points={{-10,28},{-41,28},{-41,0}}, color={0,127,255}));
      connect(res.port_b, senHPIn.port_a) annotation (Line(points={{-41,-14},
              {-42,-14},{-42,-73},{-36,-73}},
                                    color={0,127,255}));
      connect(AmbBou.ports[1], MixBox.port_Out) annotation (Line(points={{-84,61.2},
              {-70,61.2},{-70,51.2},{-66,51.2}},
                                              color={0,127,255}));
      connect(MixBox.port_Sup, heaCoi.port_a1) annotation (Line(points={{-40,51.2},
              {-16,51.2},{-16,40},{-10,40}},color={0,127,255}));
      connect(heaCoi.port_b1, SupFan.port_a)
        annotation (Line(points={{10,40},{30,40},{30,42},{36,42}},
                                                   color={0,127,255}));
      connect(SupFan.port_b, senSup.port_a) annotation (Line(points={{52,42},
              {68,42},{68,43},{74,43}},
                                color={0,127,255}));
      connect(senSup.port_b, res1.port_a)
        annotation (Line(points={{88,43},{115,43},{115,54}}, color={0,127,255}));
      connect(senRet.port_b, RetFan.port_a) annotation (Line(points={{40,79},
              {28,79},{28,78},{22,78}},
                                color={0,127,255}));
      connect(RetFan.port_b, res2.port_a) annotation (Line(points={{6,78},{4,77},
              {-12,77}}, color={0,127,255}));
      connect(res2.port_b, MixBox.port_Ret) annotation (Line(points={{-26,77},
              {-36,77},{-36,66.8},{-40,66.8}},
                                      color={0,127,255}));
      connect(MixBox.port_Exh, AmbBou.ports[2]) annotation (Line(points={{-66,66.8},
              {-80,66.8},{-80,62.8},{-84,62.8}},color={0,127,255}));
      connect(TOut.y, preTem.T) annotation (Line(points={{-147.4,105},{19,105}},
                          color={238,46,47}));
      connect(preTem.port, Zone.extWall)
        annotation (Line(points={{30,105},{50,105},{50,100},{68,100}},
                                                     color={191,0,0}));
      connect(beta.y, MixBox.y) annotation (Line(points={{-67.4,28},{-53,28},
              {-53,43.4}},
            color={0,0,127}));
      connect(TOut.y, AmbBou.T_in) annotation (Line(points={{-147.4,105},{-108,105},
              {-108,65.2},{-101.6,65.2}}, color={238,46,47}));
      connect(senHPOut.port_b, expVes.port_a) annotation (Line(points={{48,-73},
              {48,-74},{70,-74},{70,-55}},
                                       color={0,127,255}));
      connect(expVes.port_a, WatPum.port_a) annotation (Line(points={{70,-55},
              {70,-56},{68,-56},{68,-18}},
                                  color={0,127,255}));

      connect(qIntRad.port, Zone.intGainsRad) annotation (Line(points={{138,123},
              {120,123},{120,112},{116,112}},
                                         color={191,0,0}));
      connect(qIntConv.port, Zone.intGainsConv) annotation (Line(points={{138,111},
              {120,111},{120,108},{116,108}}, color={191,0,0}));
      connect(Sol.y, Zone.solRad[1]) annotation (Line(points={{36.6,119},{67,119}},
              color={0,0,127}));
      connect(IntGains.y[1], qIntRad.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,123},{152,123}}, color={0,0,127}));
      connect(IntGains.y[2], qIntConv.Q_flow) annotation (Line(points={{-99,132},
              {158,132},{158,111},{152,111}}, color={0,0,127}));
      connect(mDot.y, WatPum.m_flow_in) annotation (Line(points={{44.6,-11},
              {44.6,-10},{58.4,-10}}, color={0,0,127}));
      connect(senRet.port_a, Zone.ports[1]) annotation (Line(points={{54,79},{
              106.237,79},{106.237,86.05}},  color={0,127,255}));
      connect(res1.port_b, Zone.ports[2]) annotation (Line(points={{115,68},{
              115,82},{107.763,82},{107.763,86.05}},
                                             color={0,127,255}));
      connect(preTem.port, Zone.window) annotation (Line(points={{30,105},{48,105},
              {48,106},{68,106},{68,108}}, color={191,0,0}));
      connect(senHPIn.T, to_degC.u) annotation (Line(points={{-29,-65.3},{-46,-65.3},
              {-46,-60},{-70,-60},{-70,-70},{-63.2,-70}}, color={0,0,127}));
      connect(TSup.y, firstOrder.u) annotation (Line(points={{-17.4,-53},{-17.4,-26},
              {-10,-26},{-10,-42}}, color={0,0,127}));
      connect(firstOrder.y, heaPum.TSet) annotation (Line(points={{13,-42},{18,-42},
              {18,-62},{-12,-62},{-12,-69}}, color={0,0,127}));

      // 新增：送风流量控制连接
      connect(mSupCmdRaw.y, supFlowLimiter.u) annotation (Line(points={{218.6,
              66},{222,66},{222,56},{200,56},{200,66},{195.2,66}},
                                          color={0,0,127}));
      connect(supFlowLimiter.y, supFlowFilter.u) annotation (Line(points={{181.4,
              66},{174,66},{174,86},{167.2,86}},
                           color={0,0,127}));
      connect(supFlowFilter.y, SupFan.m_flow_in) annotation (Line(points={{153.4,
              86},{130,86},{130,28},{70,28},{70,30},{62,30},{62,58},{44,58},{44,
              51.6}},                               color={0,0,127}));
      connect(supFlowFilter.y, RetFan.m_flow_in) annotation (Line(points={{153.4,
              86},{130,86},{130,28},{70,28},{70,30},{62,30},{62,92},{14,92},{14,
              87.6}},                               color={0,0,127}));

      annotation (
        uses(Buildings(version="12.1.0")),
        experiment(
          StopTime=432000,
          Interval=60,
          __Dymola_Algorithm="Dassl"),
        Diagram(coordinateSystem(extent={{-200,-120},{180,160}})),
        Icon(coordinateSystem(extent={{-200,-120},{180,160}})));
    end D20250112_20250116;
  end AHU_datareverse;
  annotation (uses(Buildings(version="12.1.0"), Modelica(version="4.0.0")));
end ASHP_guohe;
