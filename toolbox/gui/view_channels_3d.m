function [hFig, iDS, iFig] = view_channels_3d(FileNames, Modality, SurfaceType, is3DElectrodes, isDetails)
% VIEW_CHANNELS_3D: Display channel files on top of subject anatomy.

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2010-2017

% Parse inputs
if (nargin < 5) || isempty(isDetails)
    isDetails = 0;
end
if (nargin < 4) || isempty(is3DElectrodes)
    is3DElectrodes = 0;
end
if (nargin < 3) || isempty(SurfaceType)
    SurfaceType = 'scalp';
end
if ischar(FileNames)
    FileNames = {FileNames};
end
hFig = [];
iDS = [];
iFig = [];
% Coils or channel markers?
isShowCoils = ismember(Modality, {'Vectorview306', 'CTF', '4D', 'KIT', 'KRISS', 'BabyMEG', 'NIRS-BRS'});

% === DISPLAY SURFACE ===
% Get study
[sStudy, iStudy] = bst_get('ChannelFile', FileNames{1});
if isempty(sStudy)
    return
end
% Get subject
sSubject = bst_get('Subject', sStudy.BrainStormSubject);
% View surface if available
if ~isempty(sSubject)
    % If displaying MEG coils: remove completely the transparency for nicer display with Matlab >= 2014b
    if isShowCoils
        opaqueAlpha = 0;
    else
        opaqueAlpha = .1;
    end
    % Display surface
    switch lower(SurfaceType)
        case 'cortex'
            if ~isempty(sSubject.iCortex) && (sSubject.iCortex <= length(sSubject.Surface))
                SurfaceFile = sSubject.Surface(sSubject.iCortex).FileName;
                switch (Modality)
                    case 'SEEG',  SurfAlpha = .8;
                    case 'ECOG',  SurfAlpha = .2;
                    otherwise,    SurfAlpha = opaqueAlpha;
                end
                hFig = view_surface(SurfaceFile, SurfAlpha, [], 'NewFigure');
            end
        case 'innerskull'
            if ~isempty(sSubject.iInnerSkull) && (sSubject.iInnerSkull <= length(sSubject.Surface))
                SurfaceFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
                switch (Modality)
                    case 'SEEG',  SurfAlpha = .5;
                    case 'ECOG',  SurfAlpha = .2;
                    otherwise,    SurfAlpha = opaqueAlpha;
                end
                hFig = view_surface(SurfaceFile, SurfAlpha, [], 'NewFigure');
            end
        case 'scalp'
            if ~isempty(sSubject.iScalp) && (sSubject.iScalp <= length(sSubject.Surface))
                SurfaceFile = sSubject.Surface(sSubject.iScalp).FileName;
                switch (Modality)
                    case 'SEEG',  SurfAlpha = .8;
                    case 'ECOG',  SurfAlpha = .8;
                    case 'NIRS-BRS'
                        if isDetails
                            SurfAlpha = .8;
                        else
                            SurfAlpha = opaqueAlpha;
                        end
                    otherwise
                        SurfAlpha = opaqueAlpha;
                end
                hFig = view_surface(SurfaceFile, SurfAlpha, [], 'NewFigure');
            end
        case 'anatomy'
            if ~isempty(sSubject.iAnatomy) && (sSubject.iAnatomy <= length(sSubject.Anatomy))
                MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
                SurfAlpha = .1;
                hFig = view_mri_3d(MriFile, [], SurfAlpha, 'NewFigure');
            end
    end
end
% Warning if no surface was found
if isempty(hFig)
    disp('BST> Warning: The anatomy of this subject was not imported properly.');
end

% === DISPLAY CHANNEL FILES ===
% Only one: Markers and labels 
if (length(FileNames) == 1)
    if is3DElectrodes
        isLabels = 0;
    else
        isLabels = 1;
    end
    isMarkers = ~isShowCoils || isDetails;
    [hFig, iDS, iFig] = view_channels(FileNames{1}, Modality, isMarkers, isLabels, hFig, is3DElectrodes);
% Multiple: Markers only
else
    ColorTable = [1,0,0; 0,1,0; 0,0,1];
    for i = 1:length(FileNames)
        color = ColorTable(mod(i-1,size(ColorTable,1))+1,:);
        % View channel file
        [hFig, iDS, iFig] = view_channels(FileNames{i}, Modality, 1, 0, hFig);
        % Rename objects so that they are not deleted by the following call
        hPatch = findobj(hFig, 'tag', 'SensorsPatch');
        set(hPatch, 'FaceColor', color, 'FaceAlpha', .3, 'SpecularStrength', 0, ...
                    'EdgeColor', color, 'EdgeAlpha', .2, 'LineWidth', 1, ...
                    'Marker', 'none', 'Tag', 'MultipleSensorsPatches');
        if (i ~= length(FileNames))
            hPatch = copyobj(hPatch, get(hPatch,'Parent'));
        end
    end
end

