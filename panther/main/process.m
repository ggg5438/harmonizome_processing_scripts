


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

% initialize lists structure
gene_atb.edges = edgesinit(175738, [], 'UniProtAcc', [], 'UniProtAcc', [], [], [], 'Pathway', [], 'Panther ID', [], [], false, []);

% read data
fid = fopen('input/dataset_20160406_original.txt', 'r');
for i = 1:1:gene_atb.edges.numedges
    currline = fgetl(fid);
    currcells = strsplitbyadr(currline, '\t');
    gene_atb.edges.targetdesc{i} = strtrim(currcells{1});
    gene_atb.edges.target{i} = strtrim(currcells{2});
    uniprotacc = regexp(currcells{5}, 'UniProtKB=(?<uniprotacc>[a-zA-Z0-9-]+)', 'names');
    gene_atb.edges.source{i} = uniprotacc.uniprotacc;
    gene_atb.edges.sourcedesc{i} = uniprotacc.uniprotacc;
end
fclose(fid);
discard = cellfun(@isempty, gene_atb.edges.source) | strcmp(gene_atb.edges.source, '') | cellfun(@isempty, gene_atb.edges.target) | strcmp(gene_atb.edges.target, '') | cellfun(@isempty, gene_atb.edges.targetdesc) | strcmp(gene_atb.edges.targetdesc, '');
gene_atb.edges = edgesdiscard(gene_atb.edges, discard);
clear fid i currline currcells uniprotacc ans discard;

% convert to matrix format
gene_atb.cm = edges2cm(edgesunique(gene_atb.edges));
gene_atb = rmfield(gene_atb, 'edges');

% map gene symbols to entrez gene symbols and discard rows corresponding to un-mapped symbols
% 19305 unmapped out of 21400 (90%) *other species in file
[gene_atb.cm.term, gene_atb.cm.termname, gene_atb.cm.termid, gene_atb.cm.termidname, discard] = uniprot2entrez(gene_atb.cm.termdesc, 'human', mappingfilespath);
gene_atb.cm = cmrowdiscard(gene_atb.cm, discard);
disp([num2str(sum(discard)) ' unmapped out of ' num2str(numel(discard)) ' (' num2str(round(100*sum(discard)/numel(discard))) '%)']);
clear discard;

% merge rows corresponding to the same gene
if numel(unique(gene_atb.cm.term)) < gene_atb.cm.numterms
    gene_atb.cm = cmrowmerge(gene_atb.cm, 'max');
end

% remove empty rows and cols
gene_atb.cm = cmtrim(gene_atb.cm, 1, Inf, 1, Inf);

% save cleaned data
gene_atb.cm.matrix = sparse(gene_atb.cm.matrix);
save('output/gene_attribute_matrix_cleaned.mat', '-struct', 'gene_atb');
gene_atb.cm.matrix = full(gene_atb.cm.matrix);

% standardize
tftype = 'raw'; % doesn't matter for binary data
gene_atb.cm = cm_tfidf_standardization(gene_atb.cm, tftype);
figure(1); clf; hist(gene_atb.cm.matrix(gene_atb.cm.matrix~=0), 100);
support = 'unbounded';
fignum = 2;
gene_atb.cm = cm_ksdensity_standardization_sparsematrix(gene_atb.cm, support, fignum);
clear tftype support fignum;

% cluster and view standardized matrix
gene_atb.cm = cmcluster_nogram(gene_atb.cm, true);

% save standardized data
gene_atb.cm.matrix = sparse(gene_atb.cm.matrix);
save('output/gene_attribute_matrix_standardized.mat', '-struct', 'gene_atb');
gene_atb.cm.matrix = full(gene_atb.cm.matrix);
writecm('output/gene_attribute_matrix_standardized', gene_atb.cm);
gzip('output/gene_attribute_matrix_standardized.txt');
delete('output/gene_attribute_matrix_standardized.txt');
genes = gene_atb.cm.term;
atbs = gene_atb.cm.entry;

% threshold
gene_atb.cm.matrix = (gene_atb.cm.matrix > 0) - (gene_atb.cm.matrix < 0);

% save thresholded data
gene_atb.cm.matrix = sparse(gene_atb.cm.matrix);
save('output/gene_attribute_matrix_thresholded.mat', '-struct', 'gene_atb');
gene_atb.cm.matrix = full(gene_atb.cm.matrix);
writecm('output/gene_attribute_matrix_thresholded', gene_atb.cm);
gzip('output/gene_attribute_matrix_thresholded.txt');
delete('output/gene_attribute_matrix_thresholded.txt');
clear gene_atb;

% align cleaned matrix with standardized matrix and save
load('output/gene_attribute_matrix_cleaned.mat', '-mat', 'cm');
cm = conmatmap(cm, genes, atbs);
save('output/gene_attribute_matrix_cleaned.mat', '-mat', 'cm');
writecm('output/gene_attribute_matrix_cleaned', cm);
gzip('output/gene_attribute_matrix_cleaned.txt');
delete('output/gene_attribute_matrix_cleaned.txt');
clear cm genes atbs mappingfilespath;


