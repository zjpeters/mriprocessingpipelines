%% Matlab script to create an BIDS compatible participants.tsv file
% Creates basic participants.tsv and sessions.tsv files for each
% subject/session with participant_id and session_id as the headers
% by Zeru Peterson, 2021
function createParticipantsTsv(rawdataLocation)
    % where you want to save the participants file to
    rawdata = fullfile(rawdataLocation);
    participants_tsv_name = fullfile(rawdata, 'participants.tsv');
    
    %% table for participants
    % assumes that data is already labeled with sub-###### notation. if
    % different, change next line
    dir_info = dir(fullfile(rawdata,'sub-*'));    % this collects all of the folders that follow the BIDS naming format
    dir_info = struct2table(dir_info);
    
    for i = 1:height(dir_info)
        participant_id{i} = dir_info(i,:).name;
    end
    participant_id = participant_id';
    participantsTable = table(participant_id);
    writetable(participantsTable, fullfile(rawdata, 'participants.tsv'), 'FileType', 'text', 'Delimiter', '\t');
    %% table for sessions
    
    for i = 1:height(dir_info)
        act_ses_info = dir(fullfile(rawdata,char(dir_info(i,:).name), 'ses-*'));
        for j = 1:height(act_ses_info)
            session_id{j} = act_ses_info(j,:).name;
        end
        
        session_id = session_id';
        sessionsTable = table(session_id);
        writetable(sessionsTable, fullfile(rawdata,char(dir_info(i,:).name), 'sessions.tsv'), 'FileType', 'text', 'Delimiter', '\t');
        clear session_id sessionsTable;
    end
end
