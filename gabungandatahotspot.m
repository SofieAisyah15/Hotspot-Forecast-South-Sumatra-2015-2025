%% ============================================================
% MEMBUAT DATA HOTSPOT HARIAN SUMATERA SELATAN
% PERIODE 2015-2025
% ============================================================

clc;
clear;
close all;

%% 1. FOLDER DATA

folderHotspot = ...
    'C:\Users\LENOVO\Downloads\data skripsi\data hotspot';

% GANTI dengan lokasi shapefile Sumatera Selatan kamu
shpFile = ...
    "C:\Users\LENOVO\Downloads\data skripsi\shapefile Sumatera Selatan\SumateraSelatan2D.shp";

outputFile = ...
    'C:\Users\LENOVO\Downloads\data skripsi\data hotspot\hotspot_sumsel_2015_2025.csv';


%% 2. BACA SHAPEFILE SUMATERA SELATAN

S = shaperead(shpFile);

fprintf('Shapefile berhasil dibaca.\n');
fprintf('Jumlah polygon = %d\n',length(S));


%% 3. BACA SEMUA DATA HOTSPOT 2015-2025

semuaHotspot = table();

for tahun = 2015:2025

    fileName = fullfile(folderHotspot,...
        sprintf('%d.csv',tahun));

    fprintf('\nMembaca %d.csv...\n',tahun);

    if ~isfile(fileName)
        warning('File %d.csv tidak ditemukan.',tahun);
        continue;
    end

    T = readtable(fileName,...
        'Delimiter',';',...
        'VariableNamingRule','preserve');

    fprintf('Jumlah data awal = %d\n',height(T));

    %% Pastikan acq_date menjadi datetime

    if ~isdatetime(T.acq_date)

        try
            T.acq_date = datetime(T.acq_date,...
                'InputFormat','yyyy-MM-dd');
        catch

            T.acq_date = datetime(T.acq_date);

        end

    end

    %% Gabungkan

    semuaHotspot = [semuaHotspot; T];

end

fprintf('\n======================================\n');
fprintf('DATA HOTSPOT GABUNGAN\n');
fprintf('======================================\n');

fprintf('Total hotspot Indonesia = %d\n',...
    height(semuaHotspot));


%% 4. FILTER HOTSPOT YANG MASUK SUMATERA SELATAN

lat = semuaHotspot.latitude;
lon = semuaHotspot.longitude;

diSumsel = false(height(semuaHotspot),1);

for k = 1:length(S)

    % Beberapa shapefile memiliki bagian polygon
    % dengan NaN sebagai pemisah

    in = inpolygon(lon,lat,S(k).X,S(k).Y);

    diSumsel = diSumsel | in;

end

hotspotSumsel = semuaHotspot(diSumsel,:);

fprintf('\n======================================\n');
fprintf('FILTER SUMATERA SELATAN\n');
fprintf('======================================\n');

fprintf('Hotspot di Sumatera Selatan = %d\n',...
    height(hotspotSumsel));


%% 5. HITUNG JUMLAH HOTSPOT PER HARI

tanggalHotspot = hotspotSumsel.acq_date;

tanggalMulai = datetime(2015,1,1);
tanggalAkhir = datetime(2025,12,31);

semuaTanggal = (tanggalMulai:tanggalAkhir)';

jumlahHotspot = zeros(length(semuaTanggal),1);

for i = 1:length(semuaTanggal)

    jumlahHotspot(i) = sum( ...
        tanggalHotspot == semuaTanggal(i));

end


%% 6. BUAT TABEL FINAL

hotspotDaily = table( ...
    semuaTanggal,...
    jumlahHotspot,...
    'VariableNames',{'Date','Hotspot'});


%% 7. CEK HASIL

fprintf('\n======================================\n');
fprintf('HASIL HOTSPOT HARIAN\n');
fprintf('======================================\n');

fprintf('Jumlah hari = %d\n',...
    height(hotspotDaily));

fprintf('Tanggal awal = %s\n',...
    datestr(hotspotDaily.Date(1)));

fprintf('Tanggal akhir = %s\n',...
    datestr(hotspotDaily.Date(end)));

fprintf('Total hotspot = %d\n',...
    sum(hotspotDaily.Hotspot));

fprintf('Hari dengan hotspot = %d\n',...
    sum(hotspotDaily.Hotspot > 0));

fprintf('Hari tanpa hotspot = %d\n',...
    sum(hotspotDaily.Hotspot == 0));


%% 8. TAMPILKAN CONTOH DATA

disp(' ');
disp('10 data pertama:');

disp(hotspotDaily(1:10,:));


%% 9. SIMPAN

writetable(hotspotDaily,outputFile);

fprintf('\n======================================\n');
fprintf('BERHASIL DISIMPAN\n');
fprintf('======================================\n');

fprintf('%s\n',outputFile);