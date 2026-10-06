* 在线云编译自己的padavan设备固件（原 auto-padavan / Padavan-build / Padavan-Build-TB 三仓库已整合至此）
* 支持修改默认IP,支持自定义增减插件
* 源码更新后自动编译已配置设备固件

#### 工作流一览 ####
* `K2P-512-Build.yml` — K2P-USB-512（a0575/padavan，含 SS 3.3.6 核心更新 + 卡死自动恢复看门狗）
* `Diy Build.yml` — 自定义配置编译（a0575/padavan，repository_dispatch 触发）
* `build-padavan.yml` — 推送 v* 标签或发布 Release 时编译 K2P-USB-512
* `Hanwckf_CI.yml` — hanwckf/rt-n56u 源码，多设备矩阵编译
* `Hanwckf_4.4_kernal_CI.yml` — hanwckf/padavan-4.4 源码
* `MeIsReallyBa_4.4_kernal_CI.yml` — MeIsReallyBa/padavan-4.4 源码（K2P / R2100）
* `vb1980_kvr_CI.yml` — vb1980/Padavan-KVR 源码
* `update-checker.yml` — a0575/padavan 源码更新后自动触发编译
* `Test.yml` — 测试用编译
* `delete_old_workflow_runs.yml` — 手动清理历史运行记录

注意：TB 系列工作流仅在**仓库 owner 本人点 Star** 或手动 `Run workflow` 时运行（`if: owner.id == sender.id`）。

#### 固件说明 ####
* 默认登陆IP:192.168.123.1（TB 系列为 192.168.2.1）
* 默认用户名/密码:admin/admin
* 默认wifi密码:12346789（TB 系列为 1234567890）
* 
#### 支持设备 ####
* PSG1208 /PSG1218 /NEWIFI-MINI /MI-MINI /MI-3 
* OYE-001 /5K-W20 /DIR-878 /DIR-882 /E8820V2 /JCG-Y2 K2P
* HC5861B /MI-NANO /MZ-R13 /MZ-R13P /360P2 /HC5761A 
* HC5661A /K2P_nano /MR2600 /MR2600-5.0 /JCG-836PRO
* K2P_nano-5.0 /K2P-5.0 /DIR-878-5.0 /RM2100 
* PSG1218_nano /RT-AC1200GU /WDR7300 /YK-L1
* JCG-AC860M /K2P-USB-5.0 /K2P-USB /CR660x
* XY-C1 /JCG-836PRO-5.0 /JCG-AC860M-5.0 
* JCG-Y2-5.0 /DIR-882-5.0 /A3004NS /MSG1500 /WR1200JS 
* MI-R3G /NEWIFI3 /B70 /MI-3C /MI-R3P /MI-R3P-breed /MI-R4A 
* NETGEAR-BZV /NETGEAR-CHJ /R2100 /R6220 /ZTE_E8820S
* GHL JCG-AC836M /JCG-AC856M-5.0 /JDC-1-5.0 /JDC-1 
* K2P-USB-512 /MSG1500-7615 /MZ-R18 /NEWIFI-D1 /PSG712 /RE6500 
