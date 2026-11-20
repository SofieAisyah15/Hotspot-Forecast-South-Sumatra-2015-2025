%% ============================================================
%  FIRE HOTSPOT FORECAST EVALUATION - LEAKAGE-FREE VERSION
%  Persistence vs Climate-all vs Phase-space, lead 1-14 days
% ============================================================
clc; clear; close all;

%% 0a. GLOBAL FONT 
set(groot,'DefaultAxesFontSize',16, ...
          'DefaultAxesFontName','Arial', ...
          'DefaultAxesTitleFontWeight','bold', ...
          'DefaultAxesTitleFontSizeMultiplier',1.35, ...
          'DefaultAxesLabelFontSizeMultiplier',1.1, ...
          'DefaultLegendFontSize',15);

%% 0b. CONFIG
cfg.tau            = 7;
cfg.m              = 3;
cfg.maxLead        = 14;
cfg.windowSize     = 365;
cfg.horizon        = 90;
cfg.selectedLeads  = [1 4 10 14];
cfg.nTrees         = 100;
cfg.seed           = 42;
cfg.climateLearner = 'svm';    
cfg.useLog1p       = false;
cfg.minTrain       = 30;
cfg.ninoMode       = 'interp';
cfg.ninoLagDays    = 60;
cfg.ninoPlotStart  = datetime(2016,1,1);  
cfg.saveFigs       = true;     % simpan PNG 300 dpi

if cfg.useLog1p
    tf  = @(y) log1p(y);
    itf = @(z) max(expm1(z),0);
else
    tf  = @(y) y;
    itf = @(z) z;
end

%% 1. IMPORT HOTSPOT DATA
hotspotTbl = readtable('hotspot_sumsel_2015_2025.csv','VariableNamingRule','preserve');
hotspotTbl.Properties.VariableNames = {'day','mon','year','hotspots'};
dates_hotspot = datetime(hotspotTbl.year, hotspotTbl.mon, hotspotTbl.day);
hotspot = hotspotTbl.hotspots;

% ---------- PLOT 1: Daily hotspots ----------
figure('Color','w','Position',[100 100 1500 650])
plot(dates_hotspot,hotspot,'r','linewidth',1.2)
grid on
hold on
ylabel('Hotspots')
xlabel('Year')
title('Daily Hotspots in South Sumatra')
set(gca,'FontSize',14)
if cfg.saveFigs, exportgraphics(gcf,'Fig1_Hotspots.png','Resolution',300); end

%% 2. IMPORT MONTHLY NINO3.4
fid = fopen('nino.txt','r');
n34_data = textscan(fid,'%d %f %f %f %f %f %f %f %f %f %f %f %f','Delimiter',' ','MultipleDelimsAsOne',true);
fclose(fid);
years = n34_data{1};
n34_matrix = cell2mat(n34_data(2:end));
n34_matrix(n34_matrix == -99.99) = NaN;
n34_monthly = reshape(n34_matrix',[],1);
nyears  = length(years);
yearVec = repelem(double(years),12);
monthVec = repmat(1:12,1,nyears);
months_n34 = datetime(yearVec(:),monthVec(:),1);

%% 3. IMPORT DAILY WEATHER
weatherTbl = readtable('weather2.txt','FileType','text','Delimiter','\t','VariableNamingRule','preserve');
weatherTbl.Properties.VariableNames = {'YEAR','mon','DOY','T2M','RH2M','WS2M','WD10M','PRECTOTCORR'};

vals = weatherTbl{:,4:8};
vals(vals == -999) = NaN;
weatherTbl{:,4:8} = vals;
fprintf('NaN cuaca per kolom: %s\n', mat2str(sum(isnan(vals))));

if max(weatherTbl.DOY) > 31
    dates_weather = datetime(weatherTbl.YEAR,1,1) + days(weatherTbl.DOY-1);
else
    dates_weather = datetime(weatherTbl.YEAR, weatherTbl.mon, weatherTbl.DOY);
end
fprintf('Cuaca: %s s/d %s, %d baris, %d tanggal unik\n', ...
    string(min(dates_weather)), string(max(dates_weather)), height(weatherTbl), numel(unique(dates_weather)));

% ---------- PLOT 2: Daily weather (2x2) ----------
figure('Color','w','Position',[100 100 1600 1000])
tl = tiledlayout(2,2,'TileSpacing','loose','Padding','loose');

nexttile
plot(dates_weather,weatherTbl.T2M,'r','linewidth',1)
grid on
hold on
ylabel('Temperature (°C)')
title('Temperature','FontSize',14)

nexttile
plot(dates_weather,weatherTbl.PRECTOTCORR,'b','linewidth',1)
grid on
hold on
ylabel('Precipitation (mm/day)')
title('Precipitation','FontSize',14)

nexttile
plot(dates_weather,weatherTbl.WS2M,'g','linewidth',1)
grid on
hold on
ylabel('Wind speed (m/s)')
title('Wind Speed','FontSize',14)

nexttile
plot(dates_weather,weatherTbl.RH2M,'m','linewidth',1)
grid on
hold on
ylabel('Relative humidity (%)')
title('Relative Humidity','FontSize',14)

sgtitle(tl,'Daily Weather in South Sumatra','FontWeight','bold','FontSize',14)
if cfg.saveFigs, exportgraphics(gcf,'Fig2_Weather.png','Resolution',300); end

%% 4. ALIGN HOTSPOT AND WEATHER
[commonDates, iaHotspot, iaWeather] = intersect(dates_hotspot, dates_weather);
Y_hotspot = hotspot(iaHotspot);
Precip = weatherTbl.PRECTOTCORR(iaWeather);
Temp   = weatherTbl.T2M(iaWeather);
RH     = weatherTbl.RH2M(iaWeather);
Wind   = weatherTbl.WS2M(iaWeather);
fprintf('Tanggal hotspot %d | cuaca %d | cocok %d\n', ...
    numel(unique(dates_hotspot)), numel(unique(dates_weather)), numel(commonDates));
assert(all(diff(commonDates)==days(1)), ...
    'Deret gabungan tidak kontinu: ada tanggal hilang. Isi dengan NaN dulu.');

%% 5. NINO3.4 HARIAN 
switch cfg.ninoMode
    case 'hold'
        mIdx = interp1(datenum(months_n34), (1:numel(months_n34))', datenum(commonDates), 'previous', NaN);
        ENSO_daily_lin = nan(size(mIdx));
        ok = ~isnan(mIdx) & mIdx > 1;
        ENSO_daily_lin(ok) = n34_monthly(mIdx(ok) - 1);
    case 'interp'
        mid = months_n34 + days(14);
        tq  = commonDates - days(cfg.ninoLagDays);
        ENSO_daily_lin = interp1(datenum(mid), n34_monthly, datenum(tq), 'linear', NaN);
    otherwise
        error('cfg.ninoMode harus ''hold'' atau ''interp''.');
end

% ---------- PLOT 3: Daily Nino 3.4  ----------
figure('Color','w','Position',[100 100 1500 650])
plot(commonDates,ENSO_daily_lin,'k','linewidth',1.5)
axis tight
grid on
hold on
ylabel('Nino 3.4 Index')
xlabel('Year')
title(sprintf('Daily Interpolated Nino 3.4',cfg.ninoMode))
set(gca,'FontSize',14)
if cfg.saveFigs, exportgraphics(gcf,'Fig3_Nino34.png','Resolution',300); end

%% 6. DROUGHT INDICES 
spi3 = compute_spi(Precip,90);
hth  = compute_hth(Precip,1);
kbdi = compute_kbdi(Precip,Temp);

% ---------- PLOT 4: SPI-like, HTH, KBDI (3x1) ----------
figure('Color','w','Position',[100 100 1500 1000])
tl = tiledlayout(3,1,'TileSpacing','loose','Padding','loose');

nexttile
plot(commonDates,spi3,'b','linewidth',1)
grid on
hold on
ylabel('SPI-like')

nexttile
plot(commonDates,hth,'r','linewidth',1)
grid on
hold on
ylabel('HTH (days)')

nexttile
plot(commonDates,kbdi,'g','linewidth',1)
grid on
hold on
ylabel('KBDI')

xlabel(tl,'Year','FontSize',16)
sgtitle(tl,'SPI-like, HTH, and KBDI in South Sumatra','FontWeight','bold','FontSize',14)
if cfg.saveFigs, exportgraphics(gcf,'Fig4_Indices.png','Resolution',300); end

%% 7. CLIMATE PREDICTORS
doy = day(commonDates,'dayofyear');
X_climate_all = [Precip Temp RH Wind ENSO_daily_lin spi3 hth kbdi ...
                 sin(2*pi*doy/365) cos(2*pi*doy/365)];

%% 8. REMOVE INVALID ROWS 
validRows = all(isfinite(X_climate_all),2) & isfinite(Y_hotspot);
X_climate_all = X_climate_all(validRows,:);
Y_hotspot     = Y_hotspot(validRows);
commonDates   = commonDates(validRows);
Precip = Precip(validRows); Temp = Temp(validRows); RH = RH(validRows); Wind = Wind(validRows);
ENSO_daily_lin = ENSO_daily_lin(validRows);
spi3 = spi3(validRows); hth = hth(validRows); kbdi = kbdi(validRows);

assert(all(diff(commonDates)==days(1)), ...
    'Setelah filter, deret tidak kontinu: indeks tidak sama dengan hari.');

%% 9. ROLLING-ORIGIN VALIDATION
N = numel(Y_hotspot);
tau = cfg.tau; m = cfg.m; maxLead = cfg.maxLead;
windowSize = cfg.windowSize; horizon = cfg.horizon;
nRolls = floor((N - windowSize - horizon)/horizon) + 1;
assert(nRolls >= 1, 'Data tidak cukup untuk satu fold.');
fprintf('Rolling folds: %d\n', nRolls);

rng(cfg.seed);
predCell = cell(nRolls*maxLead,1);
cnt = 0;

for r = 1:nRolls
    fprintf('Fold %d of %d\n', r, nRolls);
    trainIdx = (1:windowSize) + (r-1)*horizon;
    testIdx  = (windowSize+1:windowSize+horizon) + (r-1)*horizon;

    % ---- Climate-all: satu model per lead
    climateModels = cell(maxLead,1);
    for h = 1:maxLead
        maxTrainOrigin = trainIdx(end) - h;
        if maxTrainOrigin <= trainIdx(1), continue; end
        originTrain = trainIdx(1):maxTrainOrigin;
        targetTrain = originTrain + h;
        valid = all(~isnan(X_climate_all(originTrain,:)),2) & ~isnan(Y_hotspot(targetTrain));
        if sum(valid) < cfg.minTrain, continue; end
        climateModels{h} = fitrlinear(X_climate_all(originTrain(valid),:), ...
            tf(Y_hotspot(targetTrain(valid))), 'Learner', cfg.climateLearner);
    end

    % ---- Phase-space (delay-embedding random forest)
    phaseModels = cell(maxLead,1);
    trainSeries = Y_hotspot(trainIdx);
    Ntrain = numel(trainSeries);
    if Ntrain >= (m-1)*tau + maxLead + 1
        nPhaseTrain = Ntrain - (m-1)*tau - maxLead;
        X_phase_train = nan(nPhaseTrain,m);
        Y_phase_train = nan(nPhaseTrain,maxLead);
        for k = 1:nPhaseTrain
            t = k + (m-1)*tau;
            X_phase_train(k,:) = trainSeries(t-(m-1)*tau:tau:t);
            Y_phase_train(k,:) = trainSeries(t+(1:maxLead));
        end
        for h = 1:maxLead
            Yt = Y_phase_train(:,h);
            valid = all(~isnan(X_phase_train),2) & ~isnan(Yt);
            if sum(valid) >= cfg.minTrain
                phaseModels{h} = TreeBagger(cfg.nTrees, X_phase_train(valid,:), tf(Yt(valid)), 'Method','regression');
            end
        end
    end

    % ---- Prediksi pada fold uji
    for h = 1:maxLead
        origins = testIdx(1):(testIdx(end)-h);
        if isempty(origins), continue; end
        nO = numel(origins);
        observed    = nan(nO,1);
        predClimate = nan(nO,1);
        predPhase   = nan(nO,1);
        predPersist = nan(nO,1);

        for j = 1:nO
            origin = origins(j);
            target = origin + h;
            observed(j)    = Y_hotspot(target);
            predPersist(j) = Y_hotspot(origin);

            if ~isempty(climateModels{h})
                x0 = X_climate_all(origin,:);
                if all(~isnan(x0))
                    predClimate(j) = itf(predict(climateModels{h}, x0));
                end
            end

            if ~isempty(phaseModels{h}) && origin-(m-1)*tau >= 1
                xph = reshape(Y_hotspot(origin-(m-1)*tau : tau : origin),1,m);
                if all(~isnan(xph))
                    predPhase(j) = itf(predict(phaseModels{h}, xph));
                end
            end
        end

        cnt = cnt + 1;
        predCell{cnt} = table(repmat(r,nO,1), repmat(h,nO,1), ...
            commonDates(origins(:)), commonDates(origins(:)+h), ...
            observed, predPersist, predClimate, predPhase, ...
            'VariableNames',{'fold','lead','origin','target','obs','persist','climate','phase'});
    end
end

PRED = vertcat(predCell{1:cnt});
writetable(PRED,'Predictions_leakagefree.csv');
fprintf('Prediksi disimpan: %d baris -> Predictions_leakagefree.csv\n', height(PRED));

%% 10. POOLED SKILL (sampel sama untuk ketiga model)
leadTimes = (1:maxLead)';
R = nan(maxLead,3); E = nan(maxLead,3); A = nan(maxLead,3); nUsed = nan(maxLead,1);
for h = 1:maxLead
    s  = PRED(PRED.lead==h,:);
    ok = ~isnan(s.obs) & ~isnan(s.persist) & ~isnan(s.climate) & ~isnan(s.phase);
    s  = s(ok,:);
    nUsed(h) = height(s);
    Pm = [s.persist s.climate s.phase];
    for k = 1:3
        [R(h,k),E(h,k),A(h,k)] = skill_metrics(s.obs, Pm(:,k));
    end
end

T_skill = table(leadTimes, nUsed, ...
    R(:,1),R(:,2),R(:,3), E(:,1),E(:,2),E(:,3), A(:,1),A(:,2),A(:,3), ...
    'VariableNames',{'Lead','N','r_Persist','r_Climate','r_Phase', ...
                     'RMSE_Persist','RMSE_Climate','RMSE_Phase', ...
                     'MAE_Persist','MAE_Climate','MAE_Phase'});
disp(T_skill);
writetable(T_skill,'ModelSkill_pooled.xlsx');

% ---------- PLOT 5: Model skill  ----------
figure('Color','w','Position',[100 100 1700 580])
tl = tiledlayout(1,3,'TileSpacing','compact','Padding','loose');

nexttile
h1 = plot(leadTimes,R(:,1),'-o','linewidth',2); hold on
h2 = plot(leadTimes,R(:,2),'-s','linewidth',2);
h3 = plot(leadTimes,R(:,3),'-^','linewidth',2);
yline(0,'--','HandleVisibility','off');
xlim([1 maxLead]); xticks(1:2:maxLead)
grid on
ylabel('Correlation (r)')
xlabel('Forecast Lead Time (days)')
title('Correlation Skill')

nexttile
plot(leadTimes,E(:,1),'-o','linewidth',2); hold on
plot(leadTimes,E(:,2),'-s','linewidth',2);
plot(leadTimes,E(:,3),'-^','linewidth',2);
xlim([1 maxLead]); xticks(1:2:maxLead)
grid on
ylabel('RMSE')
xlabel('Forecast Lead Time (days)')
title('RMSE Skill')

nexttile
plot(leadTimes,A(:,1),'-o','linewidth',2); hold on
plot(leadTimes,A(:,2),'-s','linewidth',2);
plot(leadTimes,A(:,3),'-^','linewidth',2);
xlim([1 maxLead]); xticks(1:2:maxLead)
grid on
ylabel('MAE')
xlabel('Forecast Lead Time (days)')
title('MAE Skill')

lgd = legend([h1 h2 h3],{'Persistence','Climate-all','Phase-space'}, ...
    'Orientation','horizontal','Box','off');
lgd.Layout.Tile = 'south';
sgtitle(tl,'14-Day Hotspot Forecast Model Skill - South Sumatra','FontWeight','bold','FontSize',16)
if cfg.saveFigs, exportgraphics(gcf,'Fig5_ModelSkill.png','Resolution',300); end

%% 11. TIME SERIES AT SELECTED LEADS (fold terakhir, PERIODE SAMA)
tStart = datetime(1900,1,1); tEnd = datetime(2100,1,1);
for p = 1:numel(cfg.selectedLeads)
    s = PRED(PRED.fold==nRolls & PRED.lead==cfg.selectedLeads(p),:);
    tStart = max(tStart, min(s.target));
    tEnd   = min(tEnd,   max(s.target));
end

% ---------- PLOT 6: Selected leads  ----------
nL = numel(cfg.selectedLeads);
figure('Color','w','Position',[100 100 1400 1050])
tl = tiledlayout(nL,1,'TileSpacing','compact','Padding','loose');
axs = gobjects(nL,1);
yMax = 0;
for p = 1:nL
    h = cfg.selectedLeads(p);
    s = PRED(PRED.fold==nRolls & PRED.lead==h,:);
    s = s(s.target>=tStart & s.target<=tEnd,:);
    axs(p) = nexttile; hold on
    g1 = plot(s.target,s.obs,    'ro','MarkerSize',5);
    g2 = plot(s.target,s.persist,'k','linewidth',1.5);
    g3 = plot(s.target,s.climate,'b','linewidth',1.5);
    g4 = plot(s.target,s.phase,  'g','linewidth',1.8);
    xlim([tStart tEnd])
    yMax = max([yMax; s.obs; s.persist; s.climate; s.phase],[],'omitnan');
    grid on
    title(sprintf('%d-Day Forecast',h))
    xtickformat('dd MMM')
    if p < nL, set(gca,'XTickLabel',[]); end
end
linkaxes(axs,'x');
yTop = ceil(1.1*yMax/10)*10;               
for p = 1:nL
    ylim(axs(p),[0 yTop])
    yticks(axs(p),0:50:ceil(yMax/50)*50)  % 0, 50, 100
end
ylabel(tl,'Hotspot Count','FontSize',18)                 
xlabel(tl,sprintf('Target Date (%d)',year(tEnd)),'FontSize',17)
lgd = legend([g1 g2 g3 g4],{'Observed','Persistence','Climate-all','Phase-space'}, ...
    'Orientation','horizontal','Box','off');
lgd.Layout.Tile = 'south';
sgtitle(tl,'Hotspot Forecast Comparison at Selected Lead Times - South Sumatra','FontWeight','bold','FontSize',24)
if cfg.saveFigs, exportgraphics(gcf,'Fig6_SelectedLeads.png','Resolution',300); end

%% 12. OPERATIONAL FORECAST (Phase-space; dilatih pada seluruh data)
lastIdx  = N;
lastDate = commonDates(end);
futureDates = lastDate + days(1:maxLead)';

nPF = N - (m-1)*tau - maxLead;
X_pf = nan(nPF,m); Y_pf = nan(nPF,maxLead);
for k = 1:nPF
    t = k + (m-1)*tau;
    X_pf(k,:) = Y_hotspot(t-(m-1)*tau:tau:t);
    Y_pf(k,:) = Y_hotspot(t+(1:maxLead));
end
x_last = reshape(Y_hotspot(lastIdx-(m-1)*tau : tau : lastIdx),1,m);

oper_phase = nan(maxLead,1);
for h = 1:maxLead
    valid = all(~isnan(X_pf),2) & ~isnan(Y_pf(:,h));
    if sum(valid) >= cfg.minTrain
        mdl = TreeBagger(cfg.nTrees, X_pf(valid,:), tf(Y_pf(valid,h)), 'Method','regression');
        oper_phase(h) = itf(predict(mdl, x_last));
    end
end
oper_persist = repmat(Y_hotspot(end),maxLead,1);
err_phase = E(:,3);                       
lowErr = min(err_phase, oper_phase);      

T_oper = table((1:maxLead)',futureDates,oper_persist,E(:,1),oper_phase,E(:,3), ...
    'VariableNames',{'Lead','Date','Persistence','Persist_RMSE','PhaseSpace','Phase_RMSE'});
disp(T_oper); writetable(T_oper,'OperationalForecast.xlsx');

% ---------- PLOT 7: Operational forecast ----------
nDisplay = 30;                            
i0 = max(1,N-nDisplay+1);
figure('Color','w','Position',[100 100 1500 650])
hO = plot(commonDates(i0:end),Y_hotspot(i0:end),'ro-','linewidth',1.8,'MarkerSize',6);
hold on
hF = errorbar(futureDates,oper_phase,lowErr,err_phase,'g-^', ...
              'linewidth',2,'MarkerSize',8,'CapSize',10);
hX = xline(lastDate,'--k','linewidth',1.5);
axis tight
ylim([0 inf])
grid on
ylabel('Hotspot Count')
xlabel('Date')
title('14-Day Operational Hotspot Forecast (Phase-Space Model)')
legend([hO hF hX],{'Observed','Phase-space Forecast \pm RMSE','Forecast Origin'}, ...
    'Location','northwest','Box','off')
set(gca,'FontSize',16)
if cfg.saveFigs, exportgraphics(gcf,'Fig7_Operational.png','Resolution',300); end

%% ============================================================
%  HELPER FUNCTIONS
% ============================================================
function [r,rmse,mae] = skill_metrics(obs,pred)
    e = obs - pred;
    rmse = sqrt(mean(e.^2));
    mae  = mean(abs(e));
    if numel(obs) > 2 && std(obs) > 0 && std(pred) > 0
        r = corr(obs,pred);
    else
        r = NaN;
    end
end

function spi = compute_spi(rain,window)
    N = length(rain); spi = nan(N,1);
    for t = window:N
        seg = rain(t-window+1:t);
        validSeg = seg(~isnan(seg));
        if numel(validSeg) < round(0.8*window), continue; end
        mu = mean(validSeg); sigma = std(validSeg);
        if sigma > 0 && ~isnan(rain(t)), spi(t) = (rain(t)-mu)/sigma; end
    end
end

function hth = compute_hth(rain,threshold)
    N = length(rain); hth = zeros(N,1); count = 0;
    for t = 1:N
        if isnan(rain(t)),            hth(t) = NaN;
        elseif rain(t) < threshold,   count = count + 1; hth(t) = count;
        else                          count = 0; hth(t) = count;
        end
    end
end

function kbdi = compute_kbdi(rain,Tmax)
    N = length(rain); kbdi = zeros(N,1); RF = 800;
    for t = 2:N
        if isnan(rain(t)) || isnan(Tmax(t))
            kbdi(t) = NaN;
        elseif rain(t) > 5
            kbdi(t) = max(0,kbdi(t-1)-rain(t));
        else
            dKBDI = (0.968 * exp(0.0486*Tmax(t))) * (RF-kbdi(t-1))/RF;
            kbdi(t) = min(RF,kbdi(t-1)+dKBDI);
        end
    end
end
