function ImaGIN_spm_eeg_convertmat2ana_3D(S)
% 3D volume export for intracerebral EEG
%
% INPUTS:
%     S         - optional input struct
%     (optional) fields of S:
%     Fname		- matrix of EEG mat-files
%     n         - size of quadratic output image (size: n x n x 1)

% -=============================================================================
% This function is part of the ImaGIN software: 
% https://f-tract.eu/
%
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
%
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE AUTHORS
% DO NOT ASSUME ANY LIABILITY OR RESPONSIBILITY FOR ITS USE IN ANY CONTEXT.
%
% Copyright (c) 2000-2017 Inserm U1216
% =============================================================================-
%
% Authors: Stefan Kiebel, 2005  (for spm_eeg_convertmat2ana.m)
%          Olivier David        (adaptation for SEEG)

try
    Fname = S.Fname;
catch
    Fname = spm_select(inf, '\.mat$', 'Select EEG mat file');
end

Nsub = size(Fname, 1);

try
    CorticalMesh = S.CorticalMesh;
catch
    str   = 'Use cortical mesh ';
    str=spm_input(str, '+1','Yes|No');
    if strcmp(str,'Yes')
        CorticalMesh = 1;
    else
        CorticalMesh = 0;
    end
end
  
if CorticalMesh
    try 
        sMRI = S.sMRI;
    catch
        sMRI = spm_select(1, 'image', 'Select normalised MRI');
    end
    try 
        SaveMNI = S.SaveMNI;
    catch
        str   = 'Save image in';
        SaveMNI=spm_input(str, '+1','Native|MNI');
        if strcmp(SaveMNI,'Native')
            SaveMNI=0;
        else
            SaveMNI=1;
        end
    end
else
    try
        SizeSphere = S.SizeSphere;
    catch
        SizeSphere = spm_input('Size of local spheres [mm]', '+1', 'n', '5', 1);
    end
end

try
    SizeHorizon = S.SizeHorizon;
catch
    SizeHorizon = spm_input('Size of spatial horizon [mm]', '+1', 'n', '10', 1);
end

try
    n = S.n;
catch
    n = spm_input('Output image spatial resolution [mm]', '+1', 'n', '4', 1);
end

try
    TimeWindow = S.TimeWindow;
catch
    TimeWindow = spm_input('Time window positions [sec]', '+1', 'r');
end
if isempty(TimeWindow)
    TimeWindowFlag=1;
else
    TimeWindowFlag=0;
end

try
    TimeWindowWidth = S.TimeWindowWidth;
catch
    TimeWindowWidth = spm_input('Time window width [sec]', '+1', 'r');
end

try
    Atlas = S.Atlas;
catch
    str   = 'Select atlas';
    Atlas=spm_input(str, '+1','Human|Rat|Mouse|PPN');
end

try
    FileOut=S.FileOut;
catch
    FileOut=[];
end


if length(n) > 1
    error('Output image spatial resolution must be scalar');
end

if length(TimeWindowWidth) > 1
    error('Time window width must be scalar');
end

try
    interpolate_bad = S.interpolate_bad;
catch
    interpolate_bad = spm_input('Bad channels', '+1', 'b', 'Interpolate|Mask out', [1,0]);
end

spm('Pointer', 'Watch'); drawnow

% Load data set into structures
D = cell(1, Nsub);
for i = 1:Nsub
    D{i} = spm_eeg_load(deblank(Fname(i,:)));
end

% Detect which function to use for griddata3
if exist('griddata3', 'file')
    fcn_griddata3 = @griddata3;
else
    fcn_griddata3 = @oc_griddata3;
end 

for k = 1:Nsub
    
    if TimeWindowFlag
        TimeWindow=D{k}.time;
    end
    
    Ctf=sensors(D{k},'EEG');
    
    if CorticalMesh
        mesh = ImaGIN_spm_eeg_inv_mesh(sMRI, 4);
        mm        = export(gifti(mesh.tess_ctx),'patch');
        mm_mni        = export(gifti(mesh.tess_mni),'patch');
        GL      = spm_mesh_smooth(mm);

        Bad=badchannels(D{k});
        Good=setdiff(setdiff(1:nchannels(D{k}),indchantype(D{k},'ECG')),Bad);
        
        Index=cell(1,nchannels(D{k})-length(indchantype(D{k},'ECG')));
        Distance=cell(1,nchannels(D{k})-length(indchantype(D{k},'ECG')));
        for i1=Good
            d=sqrt(sum((mm.vertices-ones(size(mm.vertices,1),1)*Ctf.elecpos(i1,:)).^2,2));
            Distance{i1}=min(d);
            if Distance{i1}<=SizeHorizon
                Index{i1}=find(d==min(d))';
                Distance{i1}=Distance{i1}*ones(1,length(Index{i1}));
            end
        end
        
        ok=1;
        while ok
            ok=0;
            IndexConn=cell(1,length(Index));
            IndexNew=cell(1,length(Index));
            DistanceNew=cell(1,length(Index));
            %Croissance dans un volume
            for i1=Good
                for i2=1:length(Index{i1})
                    IndexConn{i1}=unique([IndexConn{i1} find(GL(Index{i1}(i2),:))]);
                end
                IndexNew{i1}=setdiff(IndexConn{i1},Index{i1});
                d=sqrt(sum((mm.vertices(IndexNew{i1},:)-ones(length(IndexNew{i1}),1)*Ctf.elecpos(i1,:)).^2,2));
                DistanceNew{i1}=d';
                DistanceNew{i1}=DistanceNew{i1}(find(d<=SizeHorizon));
                IndexNew{i1}=IndexNew{i1}(find(d<=SizeHorizon));
                if ~isempty(IndexNew{i1})
                    ok=1;
                    Index{i1}=[Index{i1} IndexNew{i1}];
                    Distance{i1}=[Distance{i1} DistanceNew{i1}];
                end
            end
        end
        Cind=Good;

    else
        [Cel, Cind, x, y, z, Index] = ImaGIN_spm_eeg_locate_channels(D{k}, n, interpolate_bad,SizeHorizon,Ctf,Atlas);
        [Cel2, Cind2, x2, y2, z2, Index2] = ImaGIN_spm_eeg_locate_channels(D{k}, n, interpolate_bad,SizeSphere,Ctf,Atlas);
    end

    if isfield(D{k},'time')
        time=D{k}.time;
    else
        time=0:1/D{k}.fsample:(D{k}.nsamples-1)/D{k}.fsample;
        time=time+D{k}.timeonset;
    end
    timewindow=TimeWindow;
    for i1=1:length(timewindow)
        [tmp,timewindow(i1)]=min(abs(time-TimeWindow(i1)));
    end
    timewindow=unique(timewindow);
    timewindowwidth=round(TimeWindowWidth*D{k}.fsample/2);
    
    switch Atlas
        case{'Human'}
            tmp=spm('Defaults','EEG');
            bb=tmp.normalise.write.bb;
            V = fullfile(spm('dir'), 'toolbox', 'OldNorm', 'T1.nii');
            V=spm_vol(V);
        case{'PPN'}
            bb = [[-8 -5 -20];[8 6 2]];     %Brainstem full
            V = '/Users/odavid/Documents/Data/Goetz/IRM/MRI_PPN_Small2.img';
            V=spm_vol(V);
        case{'Rat'}
            bb = [[-80 -156 -120];[80 60 10]];
            V = fullfile(spm('dir'),'atlas8','rat','template','template_T1.img');
            V=spm_vol(V);
        case{'Mouse'}
            bb = [[-48 -94 -70];[48 72 0]];
            V = fullfile(spm('dir'),'atlas8','mouse','template','template_T1.img');
            V=spm_vol(V);
    end
    n1=length(bb(1,1):n:bb(2,1));
    n2=length(bb(1,2):n:bb(2,2));
    n3=length(bb(1,3):n:bb(2,3));

    % generate data directory into which converted data goes
    [P, F] = fileparts(spm_str_manip(Fname(k, :), 'r'));
    if ~isempty(P)
        [m, sta] = mkdir(P, spm_str_manip(Fname(k, :), 'tr'));
    else
        mkdir(spm_str_manip(Fname(k, :), 'tr'));
    end
    cd(fullfile(P, F));

    %Check if it is synchrony
    if isempty(strfind(D{k}.fname,'2int'))
        FlagSyn=0;
        d = (D{k}(Cind, :,:));
    else
        FlagSyn=1;
        Nchannels=(1+sqrt(1+8*D{k}.nchannels))/2;
        M=ImaGIN_ConnectivityMatrix(Nchannels);
        tmpd=(D{k}(:, :,:));
        d=zeros(Nchannels,D{k}.nsamples);
        for i1=1:Nchannels
            [tmp1,tmp2]=find(M==i1);
            d(i1,:)=mean(tmpd(tmp2,:));
        end
        if sign(min(tmpd(:)))==sign(max(tmpd(:)))
            d1=zeros(Nchannels,D{k}.nsamples);
            d2=zeros(Nchannels,D{k}.nsamples);
            for i1=1:Nchannels
                [tmp1,tmp2]=find(M==i1);
                for i2=1:size(tmpd,2)
                    tmp1=find(tmpd(tmp2,i2)>=0);
                    if ~isempty(tmp1)
                        d1(i1,:)=mean(tmpd(tmp2(tmp1),i2),1);
                    end
                    tmp1=find(tmpd(tmp2,i2)<0);
                    if ~isempty(tmp1)
                        d2(i1,:)=mean(tmpd(tmp2(tmp1),i2),1);
                    end
                end
            end
        end
    end

    tmp=round(1000*max(abs(time(timewindow))));
    for j = timewindow % time bins
        J=round(1000*time(j));
        if tmp<1e1
            V.fname = sprintf('sample_%d.nii',J);
        elseif tmp<1e2
            V.fname = sprintf('sample_%0.2d.nii',J);
        elseif tmp<1e3
            V.fname = sprintf('sample_%0.3d.nii',J);
        elseif tmp<1e4
            V.fname = sprintf('sample_%0.4d.nii',J);
        elseif tmp<1e5
            V.fname = sprintf('sample_%0.5d.nii',J);
        elseif tmp<1e6
            V.fname = sprintf('sample_%0.6d.nii',J);
        else
            V.fname = sprintf('sample_%d.nii',J);            
        end                  
        
        win=j+ (-timewindowwidth:timewindowwidth);
        win=win(find(win>=1&win<=D{k}.nsamples));
        tmpd=mean(d(:,win),2);
        
        P=[bb(1,1),bb(1,2),bb(1,3),0,0,0,n,n,n];
        V.mat=spm_matrix(P);
        V.dim=[n1 n2 n3];
        if isfield(S,'dt')
            V.dt=S.dt;
        else
            V.dt=[64 0];    %float 64
            V.dt=[16 0];    %float 32
            V.dt=[16 0];    %float 32
        end
        
        if CorticalMesh
            
            EMap=zeros(length(GL),1);
            EMapDist=zeros(length(GL),1);
            for i1=1:length(Cind)
                if isnan(tmpd(i1))
                    map=EMapDist(Index{Cind(i1)});
                    mapZero=find(map==0);
                    EMap(Index{Cind(i1)}(mapZero))=NaN;
                else
                    map=EMap(Index{Cind(i1)});
                    mapNoNaN=find(~isnan(map));
                    mapNaN=find(isnan(map));
                    EMap(Index{Cind(i1)}(mapNoNaN))=EMap(Index{Cind(i1)}(mapNoNaN))+tmpd(i1)*(SizeHorizon-Distance{Cind(i1)}(mapNoNaN))';
                    EMapDist(Index{Cind(i1)}(mapNoNaN))=EMapDist(Index{Cind(i1)}(mapNoNaN))+SizeHorizon-Distance{Cind(i1)}(mapNoNaN)';
                    EMap(Index{Cind(i1)}(mapNaN))=tmpd(i1)*(SizeHorizon-Distance{Cind(i1)}(mapNaN))';
                    EMapDist(Index{Cind(i1)}(mapNaN))=SizeHorizon-Distance{Cind(i1)}(mapNaN)';
                end
            end
            EMap=EMap./EMapDist;
            
            if SaveMNI
                di = ImaGIN_spm_mesh_to_grid(mm_mni, V, EMap);
            else
                di = ImaGIN_spm_mesh_to_grid(mm, V, EMap);
            end
            Maskout=find(isnan(di));
            di(Maskout)=-Inf;
            di=spm_dilate(di);
            di(di==-Inf)=NaN;

            V=spm_write_vol(V,di);
        else
            di = NaN*zeros(n2,n1,n3);
            di(Index) = fcn_griddata3(Cel(:,1), Cel(:,2), Cel(:,3), tmpd,x,y,z, 'linear');
            di2 = NaN*zeros(n2,n1,n3);
            di2(Index2) = fcn_griddata3(Cel2(:,1), Cel2(:,2), Cel2(:,3), tmpd,x2,y2,z2, 'nearest');
            Index3=intersect(find(isnan(di)),Index2);
            di(Index3)=di2(Index3);
            di=permute(di,[2 1 3]);

            V=spm_write_vol(V,di);
        end
        

        if exist('d1', 'var')
            tmpd=mean(d1(:,win),2);
            di = NaN*zeros(n2,n1,n3);
            di = zeros(n2,n1,n3);
            di(Index) = fcn_griddata3(Cel(:,1), Cel(:,2), Cel(:,3), tmpd,x,y,z, 'nearest');
            %         di(Index)=1;
            di=permute(di,[2 1 3]);
            P=[bb(1,1),bb(1,2),bb(1,3),0,0,0,n,n,n];
            Vtmp=V;
            Vtmp.mat=spm_matrix(P);
            Vtmp.dim=[n1 n2 n3];
            Vtmp.dt=[64 0];
            Vtmp.dt=[16 0];
            Vtmp.fname=['pos_' V.fname];
            spm_write_vol(Vtmp,di);
            tmpd=mean(d2(:,win),2);
            di = zeros(n2,n1,n3);
            di(Index) = fcn_griddata3(Cel(:,1), Cel(:,2), Cel(:,3), tmpd,x,y,z, 'nearest');
            di=permute(di,[2 1 3]);
            P=[bb(1,1),bb(1,2),bb(1,3),0,0,0,n,n,n];
            Vtmp=V;
            Vtmp.mat=spm_matrix(P);
            Vtmp.dim=[n1 n2 n3];
            Vtmp.dt=[64 0];
            Vtmp.dt=[16 0];
            Vtmp.fname=['neg_' V.fname];
            spm_write_vol(Vtmp,di);
        end
        if FlagSyn
            dsyn=(D{k}(:, :,:));
            S=mean(dsyn(:,win),2);
            Pos=Cel;
            file=fullfile(FileOut,[spm_str_manip(V.fname,'r') '.syn']);
            save(file,'S','Pos')
            Vtmp=V;
            Vtmp.dt=[64 0];
            Vtmp.dt=[16 0];
            Vtmp.mat=spm_matrix(P);
            Vtmp.dim=[size(S,1) 1 1];
            Vtmp.fname=['syn_' V.fname];
            Vtmp=spm_write_vol(Vtmp,S);
        end
        disp(sprintf('Subject %d, time %d', k, J))
    end

    cd ..
end

spm('Pointer', 'Arrow');
