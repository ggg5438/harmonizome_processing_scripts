


clear all;

% get path to mapping files and add utilities to search path
currentpath = pwd;
parentpath = currentpath(1:find(currentpath=='\', 1, 'last')-1);
mappingfilespath = [parentpath '\mapping'];
utilitiespath = [parentpath '\utilities'];
searchpaths = strsplit(path, ';')';
if ~ismember(utilitiespath, searchpaths)
    addpath(utilitiespath, '-begin');
end
clear currentpath parentpath utilitiespath searchpaths;



%{
% initialize cm structure
gene_atb.cm = cminit(20344, 44, [], 'GeneSym', [], 'Ensemble Acc', [], [], [], 'Cell Line', [], [], [], [], []);

% read file
fid = fopen('input/rnaseq_44celllines.txt', 'r');

currline = fgetl(fid);

currcells = strsplit(currline, '\t', 'CollapseDelimiters', false);

gene_atb.cm.entry = currcells(3:end)';

for i = 1:1:gene_atb.cm.numentries
    gene_atb.cm.entry{i} = gene_atb.cm.entry{i}(1:find(gene_atb.cm.entry{i} == '.', 1, 'last')-1);
end

for i = 1:1:gene_atb.cm.numterms
    
    currline = fgetl(fid);
    
    currcells = strsplit(currline, '\t', 'CollapseDelimiters', false);
    
    gene_atb.cm.term{i} = currcells{2};
    
    gene_atb.cm.termdesc{i} = currcells{1};
    
    gene_atb.cm.matrix(i,:) = str2double(currcells(3:end));
    
end

fclose(fid);

gene_atb.cm.entrydescname = 'Origin';
gene_atb.cm.entrydesc =  repmat({'-666'}, gene_atb.cm.numentries, 1);

% cell line origin from hpa website or ccle
cl = {'a431' 'a549' 'an3ca' 'bewo' 'bj' 'caco2' 'capan2' 'daudi' 'efo21' 'hacat' 'hek293' 'hela' 'hel' 'hepg2' 'hl60' 'hmc1' 'k562' 'karpas707' 'km3' 'mcf7' 'molt4' 'nb4' 'nes' 'ntera2' 'pc3' 'rh30' 'rpmi8226' 'rt4' 'sclc21h' 'shsy5y' 'skbr3' 'skmel30' 't47d' 'thp1' 'u138mg' 'u2197' 'u251mg' 'u26684' 'u266' 'u2os' 'u698' 'u87' 'u937' 'wm115'}';
origin = {'skin' 'lung' 'endometrium' 'brain' 'skin' 'colon' 'pancreas' 'haematopoietic_and_lymphoid_tissue' 'ovary' 'skin' 'kidney' 'cervix' 'haematopoietic_and_lymphoid_tissue' 'liver' 'haematopoietic_and_lymphoid_tissue' 'haematopoietic_and_lymphoid_tissue' 'haematopoietic_and_lymphoid_tissue' 'haematopoietic_and_lymphoid_tissue' 'haematopoietic_and_lymphoid_tissue' 'breast' 'haematopoietic_and_lymphoid_tissue' 'haematopoietic_and_lymphoid_tissue' 'unspecified' 'testis' 'prostate' 'soft_tissue' 'haematopoietic_and_lymphoid_tissue' 'urinary_tract' 'lung' 'central_nervous_system' 'breast' 'skin' 'breast' 'haematopoietic_and_lymphoid_tissue' 'central_nervous_system' 'soft_tissue' 'central_nervous_system' 'haematopoietic_and_lymphoid_tissue' 'haematopoietic_and_lymphoid_tissue' 'bone' 'haematopoietic_and_lymphoid_tissue' 'central_nervous_system' 'haematopoietic_and_lymphoid_tissue' 'skin'}';

[o1, o2] = ismember(gene_atb.cm.entry, cl);
o2(o2 == 0) = [];
gene_atb.cm.entrydesc(o1) = origin(o2);

save('input/gene_cellline_hpa_mRNA_unmodified.mat', '-struct', 'gene_atb');
%}
% 20344 x 44
gene_atb = load('input/gene_cellline_hpa_mRNA_unmodified.mat', '-mat', 'cm');



% map gene symbols to entrez gene symbols and discard rows corresponding to
% un-mapped symbols (1006 rows discarded, 19338 x 44 remaining)
[gene_atb.cm.term, gene_atb.cm.termname, gene_atb.cm.termid, gene_atb.cm.termidname, discard] = genesymlookup(gene_atb.cm.term, [], 'gene', 'human', true, false, mappingfilespath);
missed = gene_atb.cm.term(discard);
gene_atb.cm = cmrowdiscard(gene_atb.cm, discard);



if sum(isnan(gene_atb.cm.matrix(:))) > 0 % TRUE
    % remove rows and columns with more than 5% missing values (0
    % rows discarded, 0 columns discarded. 19338 x 44 remaining)
    gene_atb.cm = cmnantrim_frac(gene_atb.cm, 0.95, Inf, 0.95, Inf, 'column');
end



if sum(isnan(gene_atb.cm.matrix(:))) > 0 % TRUE
    % impute remaining missing values
    gene_atb.cm = cmnanimpute(gene_atb.cm, 'median', 'row');
end



% view column distributions
figure(1);
clf;
subplot(2, 2, 1);
hist(gene_atb.cm.matrix, max([10 gene_atb.cm.numterms/100]));
subplot(2, 2, 2);
hist(gene_atb.cm.matrix(:,randperm(gene_atb.cm.numentries,4)), max([10 gene_atb.cm.numterms/100]));
subplot(2, 2, 3);
hist(gene_atb.cm.matrix(:,randperm(gene_atb.cm.numentries,4)), max([10 gene_atb.cm.numterms/100]));
subplot(2, 2, 4);
hist(gene_atb.cm.matrix(:,randperm(gene_atb.cm.numentries,4)), max([10 gene_atb.cm.numterms/100]));



% find lower detection limit
detlim = zeros([1000 gene_atb.cm.numentries]);
posmin = zeros([1 gene_atb.cm.numentries]);
pos25 = zeros([1 gene_atb.cm.numentries]);
pos50 = zeros([1 gene_atb.cm.numentries]);
pos75 = zeros([1 gene_atb.cm.numentries]);
posmax = zeros([1 gene_atb.cm.numentries]);

for i = 1:1:gene_atb.cm.numentries
    
    x = gene_atb.cm.matrix(gene_atb.cm.matrix(:,i) > 0,i);
    x = sort(x);
    detlim(:,i) = x(1:1000);
    posmin(i) = x(1);
    pos25(i) = x(round(0.25*numel(x)));
    pos50(i) = x(round(0.50*numel(x)));
    pos75(i) = x(round(0.75*numel(x)));
    posmax(i) = x(end);
    
end

figure(2);
clf;
subplot(1,2,1);
hist(log2(detlim), 100);
subplot(1,2,2);
plot(1:1:gene_atb.cm.numentries, log2(posmin), '-ok', 1:1:gene_atb.cm.numentries, log2(pos25), '-ok', 1:1:gene_atb.cm.numentries, log2(pos50), '-ok', 1:1:gene_atb.cm.numentries, log2(pos75), '-ok', 1:1:gene_atb.cm.numentries, log2(posmax), '-ok');



gene_atb.cm.matrix(gene_atb.cm.matrix == 0) = NaN;
if sum(isnan(gene_atb.cm.matrix(:))) > 0 % TRUE
    % remove rows and columns with more than 75% undetected values (1798
    % rows discarded, 0 columns discarded. 17540 x 44 remaining)
    gene_atb.cm = cmnantrim_frac(gene_atb.cm, 0.25, Inf, 0.25, Inf, 'column');
end



if sum(isnan(gene_atb.cm.matrix(:))) > 0 % TRUE
    % impute remaining undetected values
    gene_atb.cm.matrix(isnan(gene_atb.cm.matrix)) = mean(posmin)/2;
end



% log2 transform
gene_atb.cm.matrix = log2(gene_atb.cm.matrix);



% view column distributions
figure(3);
clf;
subplot(2, 2, 1);
hist(gene_atb.cm.matrix, max([10 gene_atb.cm.numterms/100]));
subplot(2, 2, 2);
hist(gene_atb.cm.matrix(:,randperm(gene_atb.cm.numentries,4)), max([10 gene_atb.cm.numterms/100]));
subplot(2, 2, 3);
hist(gene_atb.cm.matrix(:,randperm(gene_atb.cm.numentries,4)), max([10 gene_atb.cm.numterms/100]));
subplot(2, 2, 4);
hist(gene_atb.cm.matrix(:,randperm(gene_atb.cm.numentries,4)), max([10 gene_atb.cm.numterms/100]));



if numel(unique(gene_atb.cm.term)) < gene_atb.cm.numterms % TRUE
    % merge measurements corresponding to the same gene (17437 unique gene
    % symbols out of 17540 total gene symbols, 17437 x 44 remaining)
    gene_atb.cm = cmrowmerge(gene_atb.cm, 'mean');
end



% view column distributions
figure(4);
clf;
subplot(2, 2, 1);
hist(gene_atb.cm.matrix, max([10 gene_atb.cm.numterms/100]));
subplot(2, 2, 2);
hist(gene_atb.cm.matrix(:,randperm(gene_atb.cm.numentries,4)), max([10 gene_atb.cm.numterms/100]));
subplot(2, 2, 3);
hist(gene_atb.cm.matrix(:,randperm(gene_atb.cm.numentries,4)), max([10 gene_atb.cm.numterms/100]));
subplot(2, 2, 4);
hist(gene_atb.cm.matrix(:,randperm(gene_atb.cm.numentries,4)), max([10 gene_atb.cm.numterms/100]));



sm = cm2sm_cosine_nocluster(gene_atb.cm);
numidentical = sum(sm.matrix > (1 - 1e-12), 2) - 1;
suspectgenes = sm.term(numidentical > 0);
clear sm;
if ~isempty(suspectgenes) % FALSE
    % remove suspect rows that have identical values to at least one other row
    discard = ismember(gene_atb.cm.term, suspectgenes);
    gene_atb.cm = cmrowdiscard(gene_atb.cm, discard);
end



sm = cm2sm_cosine_nocluster(cmtranspose(gene_atb.cm));
numidentical = sum(sm.matrix > (1 - 1e-12), 2) - 1;
suspectattributes = sm.term(numidentical > 0);
clear sm;
if ~isempty(suspectattributes) % FALSE
    % remove suspect columns that have identical values to at least one
    % other column
    discard = ismember(gene_atb.cm.entry, suspectattributes);
    gene_atb.cm = cmcoldiscard(gene_atb.cm, discard);
end



% view distributions of row and col stats
[~] = cmrowcolstats(gene_atb.cm, true, 5);



% discard rows and cols with extremely low median or extremely low median
% absolute deviation (mad) (discarded 1569 rows and 1 col, 15868 x 43 remaining)
threshquantile = 0.001;
gene_atb.cm = cmtrim_lowmedlowmad(gene_atb.cm, threshquantile);



% view distributions of row and col stats
[~] = cmrowcolstats(gene_atb.cm, true, 6);



% cluster and view matrix
[gene_atb.cm, ~] = cmcluster(gene_atb.cm, true);



% convert to sparse matrix
gene_atb.cm.matrix = sparse(gene_atb.cm.matrix);



% save result
save('output/gene_attribute_matrix_imported.mat', '-struct', 'gene_atb');



clearvars -except gene_atb;

gene_atb.cm.matrix = full(gene_atb.cm.matrix);

% normalize, prefer KS since it is non-parametric and therefore doesn't
% assume anything about the shape of the distribution of values per row
threshfrac = 0.05; % not relevant for normalization only
type = 'tertiary';
method = 'rows';
discardemptyvectors = false;
[~, gene_atb.cm] = cmthresh_ks(gene_atb.cm, threshfrac, type, method, discardemptyvectors); % dbi = 0.0656 vs 0.0574
% gene_atb.cm.matrix = robustzscore(gene_atb.cm.matrix, 2); % dbi = 0 vs 0.0574 ???
% gene_atb.cm.matrix = zscore(gene_atb.cm.matrix, 0, 2); % dbi = 0.0664 vs 0.0574
% daviesbouldin = cm2daviesbouldin(cmtranspose(gene_atb.cm));



% search for best threshold (lowest davies-bouldin index)

threshfrac = [(0.01:0.01:0.04) (0.05:0.05:0.95) (0.96:0.01:0.99)]';
type = 'tertiary';
method = 'matrix';
discardemptyvectors = false;

daviesbouldin = zeros([numel(threshfrac) 1]);

for i = 1:1:numel(threshfrac)
    
    tm = cmthresh(gene_atb.cm, threshfrac(i), type, method, discardemptyvectors);

    daviesbouldin(i) = cm2daviesbouldin(cmtranspose(tm));
    
end

figure(7); clf; plot(threshfrac, daviesbouldin, '-ok'); ylabel('davies-bouldin index'); xlabel('threshold');
%}



% threshold.  note, we could equivalently just use cmthresh to get the
% thresholded matrix, but using cmthresh_ks here in case we ever want the
% final normalized matrix (the output that is currently "~")
threshfrac = 0.15;
type = 'tertiary';
method = 'matrix';
discardemptyvectors = true;
[gene_atb.cm, ~] = cmthresh_ks(gene_atb.cm, threshfrac, type, method, discardemptyvectors);
daviesbouldin = cm2daviesbouldin(cmtranspose(gene_atb.cm)); % dbi = 0.0700



% cluster and view matrix
[gene_atb.cm, ~] = cmcluster(gene_atb.cm, true);



% view distributions of row and col stats
[~] = cmrowcolstats(gene_atb.cm, true, 8);



% convert to sparse matrix
gene_atb.cm.matrix = sparse(gene_atb.cm.matrix);



% save result
save('output/gene_attribute_matrix_prepared.mat', '-struct', 'gene_atb');
%}






% get standardized matrix

gene_atb = load('output/gene_attribute_matrix_imported.mat', '-mat', 'cm');

threshfrac = 0.05;
type = 'tertiary';
method = 'rows';
discardemptyvectors = false;
[~, gene_atb.cm] = cmthresh_ks(gene_atb.cm, threshfrac, type, method, discardemptyvectors);

threshfrac = 0.1;
type = 'tertiary';
method = 'matrix';
discardemptyvectors = true;
[~, gene_atb.cm] = cmthresh_ks(gene_atb.cm, threshfrac, type, method, discardemptyvectors);

% cluster and view matrix
[gene_atb.cm, ~] = cmcluster(gene_atb.cm, false);

% save result
if exist('output/gene_attribute_matrix_standardized.mat', 'file') == 0
    save('output/gene_attribute_matrix_standardized.mat', '-struct', 'gene_atb');
else
    error('file already exists?!');
end


