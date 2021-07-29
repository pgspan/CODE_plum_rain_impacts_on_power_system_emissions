clear;
clc;
%% Unit MW/MWh/1000ton
Year_number=3;% Choose 2040
%% row1:CG row1:NG row1:PV row1:tie-line row5:power load row6:aerosol  
Change_trend=[1  1.30  1.09  0.74
             1  1.9   3     3.9
             1 	2.87  4.94  6.56             
             1  1.2   1.4   1.6
             1 	1.49  1.74  1.83
             1  1.03  1.06  1.09];% 

%% plum rain affected area ratio and impact degree
%% 1:jiangsu 2:anhui 3: zhejiang 4: jiangxi 5: hubei 6:shanghai 7:hunan
province_index = input('Enter a province number: ');
switch province_index
    case 1
        disp('jiangsu')
        AAS=0.8;
    case 2
        disp('anhui')
        AAS=0.77;
    case 3
        disp('zhejiang')
        AAS=0.7;
    case 4
        disp('jiangxi')
        AAS=0.45;
    case 5
        disp('hubei')
        AAS=0.53;
    case 6
        disp('shanghai')
        AAS=1;
    case 7
        disp('hunan')
        AAS=0.18;
    otherwise
        disp('Wrong Input')
        return
end

%% Unit MW/MWh/1000ton
%% plum rain affected area ratio and impact degree

province = cell(7,1);
province{1} = 'jiangsu';
province{2} = 'anhui';
province{3} = 'zhejiang';
province{4} = 'jiangxi';
province{5} = 'hubei';
province{6} = 'shanghai';
province{7} = 'hunan';

expression = strcat('FileName=''dataset_', province{province_index}, '.xlsx'';');
% expression = char(expression);
eval(expression)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('%s\n','Data input...');
unit_PV_output1=xlsread(FileName,1,'B2:B841');
unit_PV_output2=xlsread(FileName,1,'C2:C841');
unit_WT_output=xlsread(FileName,1,'D2:D841');
electric_load0=xlsread(FileName,1,'E2:E841');
Num_Capacity_CG=xlsread(FileName,1,'H2:H7')';
Capacity_CG0=xlsread(FileName,1,'I2:I7')';
Num_Capacity_NG=xlsread(FileName,1,'J4:J7')';
Capacity_NG0=xlsread(FileName,1,'K4:I7')';
Generation_type=xlsread(FileName,1,'N2:N5'); % PV,WT,RG,TL
 
%% System parameters
T=840;
cost_coal=0.37;% yuan/kWh=10^3yuan/MWh 
cost_gas=0.65;% yuan/kWh=10^3yuan/MWh 
unit_bt=200*6.9;% 10^3yuan/MWh
discount_rate=0.07;
lifetime=20;
num_CG=6;num_NG=4;
T_CG_U=[16,8,7,6,5,2]';
T_CG_D=[16,8,7,6,5,2]';
T_NG_U=[7,6,5,2]';
T_NG_D=[7,6,5,2]';
unit_carbon_coal=1.22945;unit_carbon_gas=0.3756;

%% Data change
Capacity_CG=Change_trend(1,Year_number)*Capacity_CG0;%
Capacity_NG=Change_trend(2,Year_number)*Capacity_NG0;%
cost_CG_startup=0.5*Capacity_CG;%
cost_CG_shutdown=cost_CG_startup;
cost_NG_startup=0.5*Capacity_NG;%
cost_NG_shutdown=cost_NG_startup;
C_PV=Generation_type(1,1)*Change_trend(3,Year_number);%
C_WT=Generation_type(2,1);
P_RG=Generation_type(3,1);
P_TL=Generation_type(4,1)*Change_trend(4,Year_number);%
electric_load=electric_load0*Change_trend(5,Year_number);
aerosol=Change_trend(6,Year_number);

%% Optimization variable
P_CG=sdpvar(T,num_CG);P_NG=sdpvar(T,num_NG);
P_PV1=sdpvar(T,1);P_PV2=sdpvar(T,1);curtailment_PV1=sdpvar(T,1);curtailment_PV2=sdpvar(T,1);
P_ES_cha=sdpvar(T,1);P_ES_dis=sdpvar(T,1);SOC_ES=sdpvar(T,1);curtailment_load=sdpvar(T,1);
Y_CG=intvar(T,num_CG);Z_CG=intvar(T,num_CG);U_CG=intvar(T,num_CG);
Y_NG=intvar(T,num_NG);Z_NG=intvar(T,num_NG);U_NG=intvar(T,num_NG);

U_CG_individual1=binvar(T,Num_Capacity_CG(1,1));U_CG_individual2=binvar(T,Num_Capacity_CG(1,2));U_CG_individual3=binvar(T,Num_Capacity_CG(1,3));
U_CG_individual4=binvar(T,Num_Capacity_CG(1,4));U_CG_individual5=binvar(T,Num_Capacity_CG(1,5));U_CG_individual6=binvar(T,Num_Capacity_CG(1,6));
U_NG_individual1=binvar(T,Num_Capacity_NG(1,1));U_NG_individual2=binvar(T,Num_Capacity_NG(1,2));U_NG_individual3=binvar(T,Num_Capacity_NG(1,3));U_NG_individual4=binvar(T,Num_Capacity_NG(1,4));

RS_U=1000;

clear Cons;
Cons=[];

%% Constraints of PV output
Cons=Cons+(P_PV1(:,1)+curtailment_PV1(:,1)==unit_PV_output1(:,1)*(1+aerosol)*C_PV*AAS);% Plum rain affect PV generation
Cons=Cons+(P_PV2(:,1)+curtailment_PV2(:,1)==unit_PV_output2(:,1)*(1+aerosol)*C_PV*(1-AAS));% Plum rain not affect PV generation
Cons=Cons+(0<=P_PV1(:,1));
Cons=Cons+(0<=P_PV2(:,1));
Cons=Cons+(0<=curtailment_PV1(:,1));% 
Cons=Cons+(0<=curtailment_PV2(:,1));% 

%% Constraints of carbon emissions
switch province_index
    case 1
    Cons=Cons+(unit_carbon_coal*sum(sum(P_CG))+unit_carbon_gas*sum(sum(P_NG))-68759703.07==0);
    Capacity_ES=123088.9045;%%%%%%jiangsu
    case 2
    Cons=Cons+(unit_carbon_coal*sum(sum(P_CG))+unit_carbon_gas*sum(sum(P_NG))-28554255.8==0);
    Capacity_ES=188027.6391;%%%%anhui
    case 3
    Cons=Cons+(unit_carbon_coal*sum(sum(P_CG))+unit_carbon_gas*sum(sum(P_NG))-40558446.45==0);
    Capacity_ES=118080.6491;%%%%zhejiang
    case 4 
    Cons=Cons+(unit_carbon_coal*sum(sum(P_CG))+unit_carbon_gas*sum(sum(P_NG))-9878620.853==0);
    Capacity_ES=114163.5413;%%%%jiangxi
    case 5 
    Cons=Cons+(unit_carbon_coal*sum(sum(P_CG))+unit_carbon_gas*sum(sum(P_NG))-28354080.21==0);
    Capacity_ES=129941.246;%%%%hubei
    case 6 
    Cons=Cons+(unit_carbon_coal*sum(sum(P_CG))+unit_carbon_gas*sum(sum(P_NG))-17153420.95==0);
    Capacity_ES=8162.235;%%%%shanghai
    case 7 
    Cons=Cons+(unit_carbon_coal*sum(sum(P_CG))+unit_carbon_gas*sum(sum(P_NG))-10046393.08==0);
    Capacity_ES=44997.6273;%%%%hunan
end

%% Constraints of CG and NG
for i=1:num_CG
Cons=Cons+(0<=U_CG(:,i)<=Num_Capacity_CG(1,i));
Cons=Cons+(0<=Y_CG(:,i)<=Num_Capacity_CG(1,i));
Cons=Cons+(0<=Z_CG(:,i)<=Num_Capacity_CG(1,i));
end

for i=1:num_NG
Cons=Cons+(0<=U_NG(:,i)<=Num_Capacity_NG(1,i));
Cons=Cons+(0<=Y_NG(:,i)<=Num_Capacity_NG(1,i));
Cons=Cons+(0<=Z_NG(:,i)<=Num_Capacity_NG(1,i));
end

for g=1:Num_Capacity_CG(1,1)-1
Cons=Cons+(U_CG_individual1(:,g+1)<=U_CG_individual1(:,g));
end
Cons=Cons+(U_CG_individual1(:,1)<=1);Cons=Cons+(0<=U_CG_individual1(:,Num_Capacity_CG(1,1)));
for g=1:Num_Capacity_CG(1,2)-1
Cons=Cons+(U_CG_individual2(:,g+1)<=U_CG_individual2(:,g));
end
Cons=Cons+(U_CG_individual2(:,1)<=1);Cons=Cons+(0<=U_CG_individual2(:,Num_Capacity_CG(1,2)));
for g=1:Num_Capacity_CG(1,3)-1
Cons=Cons+(U_CG_individual3(:,g+1)<=U_CG_individual3(:,g));
end
Cons=Cons+(U_CG_individual3(:,1)<=1);Cons=Cons+(0<=U_CG_individual3(:,Num_Capacity_CG(1,3)));
for g=1:Num_Capacity_CG(1,4)-1
Cons=Cons+(U_CG_individual4(:,g+1)<=U_CG_individual4(:,g));
end
Cons=Cons+(U_CG_individual4(:,1)<=1);Cons=Cons+(0<=U_CG_individual4(:,Num_Capacity_CG(1,4)));
for g=1:Num_Capacity_CG(1,5)-1
Cons=Cons+(U_CG_individual5(:,g+1)<=U_CG_individual5(:,g));
end
Cons=Cons+(U_CG_individual5(:,1)<=1);Cons=Cons+(0<=U_CG_individual5(:,Num_Capacity_CG(1,5)));
for g=1:Num_Capacity_CG(1,6)-1
Cons=Cons+(U_CG_individual6(:,g+1)<=U_CG_individual6(:,g));
end
Cons=Cons+(U_CG_individual6(:,1)<=1);Cons=Cons+(0<=U_CG_individual6(:,Num_Capacity_CG(1,6)));

for g=1:Num_Capacity_NG(1,1)-1
Cons=Cons+(U_NG_individual1(:,g+1)<=U_NG_individual1(:,g));
end
Cons=Cons+(U_NG_individual1(:,1)<=1);Cons=Cons+(0<=U_NG_individual1(:,Num_Capacity_NG(1,1)));
for g=1:Num_Capacity_NG(1,2)-1
Cons=Cons+(U_NG_individual2(:,g+1)<=U_NG_individual2(:,g));
end
Cons=Cons+(U_NG_individual2(:,1)<=1);Cons=Cons+(0<=U_NG_individual2(:,Num_Capacity_NG(1,2)));
for g=1:Num_Capacity_NG(1,3)-1
Cons=Cons+(U_NG_individual3(:,g+1)<=U_NG_individual3(:,g));
end
Cons=Cons+(U_NG_individual3(:,1)<=1);Cons=Cons+(0<=U_NG_individual3(:,Num_Capacity_NG(1,3)));
for g=1:Num_Capacity_NG(1,4)-1
Cons=Cons+(U_NG_individual4(:,g+1)<=U_NG_individual4(:,g));
end
Cons=Cons+(U_NG_individual4(:,1)<=1);Cons=Cons+(0<=U_NG_individual4(:,Num_Capacity_NG(1,4)));

for i=1:num_CG
     Cons=Cons+(0.4*Capacity_CG(1,i).*U_CG(:,i)<=P_CG(:,i)<=Capacity_CG(1,i).*U_CG(:,i));%
    for t=1:T
        if t>=T_CG_U(i,1)
           Cons=Cons+(U_CG(t,i)>=sum(Y_CG(t-T_CG_U(i,1)+1:t,i))); 
        end
        if t>=T_CG_D(i,1)
           Cons=Cons+(Num_Capacity_CG(1,i)-U_CG(t,i)>=sum(Z_CG(t-T_CG_D(i,1)+1:t,i)));
        end
    end
end

for i=1:num_NG
     Cons=Cons+(0.4*Capacity_NG(1,i).*U_NG(:,i)<=P_NG(:,i)<=Capacity_NG(1,i).*U_NG(:,i));%
    for t=1:T
        if t>=T_NG_U(i,1)
           Cons=Cons+(U_NG(t,i)>=sum(Y_NG(t-T_NG_U(i,1)+1:t,i))); 
        end
        if t>=T_NG_D(i,1)
           Cons=Cons+(Num_Capacity_NG(1,i)-U_NG(t,i)>=sum(Z_NG(t-T_NG_D(i,1)+1:t,i)));
        end
    end
end

%% Power balance, Reserve, and start-stop
for t=1:T
    Cons=Cons+(sum(P_CG(t,:))+sum(P_NG(t,:))+P_RG+P_PV1(t,1)+P_PV2(t,1)+unit_WT_output(t,1)*C_WT+P_TL-P_ES_cha(t,1)+P_ES_dis(t,1)==electric_load(t,1)-curtailment_load(t,1));%�Ķ�
if t==1    
 Cons=Cons+(sum(Capacity_CG(1,:).*U_CG(t,:))+sum(Capacity_NG(1,:).*U_NG(t,:))+P_RG+P_TL+0.5*Capacity_ES>=electric_load(t,1)+RS_U);    
else
 Cons=Cons+(sum(Capacity_CG(1,:).*U_CG(t,:))+sum(Capacity_NG(1,:).*U_NG(t,:))+P_RG+P_TL+SOC_ES(t-1,1)>=electric_load(t,1)+RS_U);    
Cons=Cons+(Y_CG(t,:)-Z_CG(t,:)==U_CG(t,:)-U_CG(t-1,:));
Cons=Cons+(Y_NG(t,:)-Z_NG(t,:)==U_NG(t,:)-U_NG(t-1,:));
end  
end

%% Constraints of ES
Cons=Cons+(0<=P_ES_cha(:,1)<=Capacity_ES/4);
Cons=Cons+(0<=P_ES_dis(:,1)<=Capacity_ES/4);
Cons=Cons+(0<=SOC_ES(:,1)<=Capacity_ES);
for t=1:T
    if t==1 % mod(t,24)
    Cons=Cons+(SOC_ES(t,1)==0.5*Capacity_ES+0.95*P_ES_cha(t,1)-P_ES_dis(t,1)/0.95);        
    else
    Cons=Cons+(SOC_ES(t,1)==SOC_ES(t-1,1)+0.95*P_ES_cha(t,1)-P_ES_dis(t,1)/0.95);
    end
end
Cons=Cons+(SOC_ES(T,1)==0.5*Capacity_ES);

%% Constraints of curtailment_load
Cons=Cons+(0<=curtailment_load(:,1));

%% CObjective function
obj=0;
for i=1:num_CG
obj=obj+cost_coal*sum(P_CG(:,i));   
obj=obj+cost_CG_startup(1,i)*sum(Y_CG(:,i));
obj=obj+cost_CG_shutdown(1,i)*sum(Z_CG(:,i));
end
for i=1:num_NG
obj=obj+cost_gas*sum(P_NG(:,i));   
obj=obj+cost_NG_startup(1,i)*sum(Y_NG(:,i));
obj=obj+cost_NG_shutdown(1,i)*sum(Z_NG(:,i));  
end

obj=obj+100*sum(curtailment_PV1)+100*sum(curtailment_PV2)+T/8760*(discount_rate*(1+discount_rate)^lifetime)/((1+discount_rate)^lifetime-1)*unit_bt*Capacity_ES+100*sum(curtailment_load);
 

    ops=sdpsettings('solver','cplex','verbose',0);
    sol=optimize(Cons,obj,ops);
    if sol.problem == 0
        fprintf('%s%.4f\n','Objective: ',value(obj));
    else
        display('Hmm, something went wrong!');
        sol.info
        yalmiperror(sol.problem)
    end  
P_CG=value(P_CG);U_CG=value(U_CG);Y_CG=value(Y_CG);Z_CG=value(Z_CG);
P_NG=value(P_NG);U_NG=value(U_NG);Y_NG=value(Y_NG);Z_NG=value(Z_NG);
SOC_ES=value(SOC_ES);P_ES_cha=value(P_ES_cha);P_ES_dis=value(P_ES_dis);curtailment_load=value(curtailment_load);
P_PV1=value(P_PV1);P_PV2=value(P_PV2);

%% Hourly power balance of 2 July to 7 July
Hourly_powerbalance=zeros(168,7);
for t=337:504
    Hourly_powerbalance(t-336,1)=value(P_RG+unit_WT_output(t,1)*C_WT+P_TL);
    Hourly_powerbalance(t-336,2)=value(P_PV1(t,1)+P_PV2(t,1));
    Hourly_powerbalance(t-336,3)=value(sum(P_CG(t,:)));
    Hourly_powerbalance(t-336,4)=value(sum(P_NG(t,:)));
    Hourly_powerbalance(t-336,5)=value(P_ES_dis(t,1));
    Hourly_powerbalance(t-336,6)=value(P_ES_cha(t,1));
    Hourly_powerbalance(t-336,7)=value(electric_load(t,1));
end

%% LCCM
switch province_index
    case 1
    LCCM=(obj-23870083.3461)/(1578460.635);
    case 2
    LCCM=(obj-11525872.0087)/(1352036.357);
    case 3
    LCCM=(obj-16123011.9360)/(1312758.533);
    case 4 
    LCCM=(obj-4682750.5571)/(462567.6893);
    case 5 
    LCCM=(obj-10867005.0253)/(248156.8846);
    case 6 
    LCCM=(obj-7285479.2442)/(164507.3758);
    case 7 
    LCCM=(obj-3636015.4696)/(58869.14306);
end




