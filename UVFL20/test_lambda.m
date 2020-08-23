%%************************************************************************
%% run random matrix completion problems. 
%% ************************************************************************
clear all;

restoredefaultpath;

addpath(genpath('solvers'));

addpath(genpath('PROPACKmod'));

%%

OPTIONS_AMM.maxiter = 5000;
        
OPTIONS_AMM.printyes = 1;

OPTIONS_AMM.tol = 1.0e-4;

OPTIONS_MAPM.maxiter = 2000;
        
OPTIONS_MAPM.printyes = 1;

OPTIONS_MAPM.tol = 5.0e-2;

OPTIONS_ALS.maxiter = 2000;
        
OPTIONS_ALS.printyes = 1;

OPTIONS_ALS.tol = 1.0e-6;
%% generate random a test problem

scenario = 'noisy';

sample_type ='nonuniform';

ntest = 5;        % number of testing

%% ************** Initialization for test problem ******************

nr = 1500;

nc = 1500;

rstar = 10;

nuAMM  = [ 3    3.5    4      4.2    4.5    4.7     5     5.2    5.5    5.8     6     6.2    6.5    6.7    7     7.2    7.5   7.8   8 ]*10; 
 
nuMAPM = [0.5   0.6    0.7    0.8    0.9     1     1.1    1.2    1.3    1.4    1.5    1.6    1.7    1.8    1.9    2     2.1   2.2  2.3 ]*10 ;    

nuALS  = [0.01  0.05   0.1    0.2    0.3    0.4    0.5     0.6   0.7    0.8     0.9     1     1.2   1.5     1.8    2    2.4    2.8    3]; 

ns = length(nuMAPM);

%% ***************** Initialization *********************************

AMM_matrelerr = zeros(ntest,ns); Brid_matrelerr = zeros(ntest,ns);  ALS_matrelerr = zeros(ntest,ns);

AMM_matrank = zeros(ntest,ns);   Brid_matrank = zeros(ntest,ns);    ALS_matrank = zeros(ntest,ns);
 
AMM_mattime = zeros(ntest,ns);   Brid_mattime = zeros(ntest,ns);    ALS_mattime = zeros(ntest,ns); 

%% ******************** main loop  **********************************************

SR = 0.2; 

for i = 1:ns
    
    i
    const_AMM  = nuAMM(i)*SR;
    
    const_MAPM = nuMAPM(i)*SR;
   
    const_ALS  = nuALS(i)*SR;
    
    for test_iter = 1:ntest
        
        test_iter
        
        randstate =  100*i*test_iter   %100*i*(100+t)
        randn('state',double(randstate));
        rand('state',double(randstate));
        
        if strcmp(scenario,'noiseless')
            noiseratio = 0;
        else
            noiseratio = 0.1;
        end
        
        fprintf('\n nr = %2.0d,   nc = %2.0d,   rank = %2.0d\n,',nr,nc,rstar);
        randn('state',double(randstate));
        rand('state',double(randstate));
        
        p = round(SR*nr*nc);     %% number of sampled entries
       
       %% *************** to generate the true matrix ******************
        
        M.U = randn(nr,rstar);
        
        M.V = randn(nc,rstar);
 
        normM = sqrt(sum(sum((M.U'*M.U).*(M.V'*M.V))));
    
        Mstar = M.U*M.V';
        
        num_sample = p;
        
       %%  ***********  uniform sampling  ***************************
        
        if strcmp(sample_type,'uniform')
            
            fprintf('\n *********** uniform sampling ***************\n \n');
           
            fprintf('\n SR = %2.2f��  noiseratio = %2.2f\n,',SR,noiseratio);
            
            idx = randperm(nr*nc);
            
            nzidx = idx(1:p)';
            
            zidx = idx(p+1:end)';
        
        elseif strcmp(sample_type,'nonuniform')
        
       %%  *************  non-uniform sampling  ********************** 
            fprintf('\n non-uniform sampling\n');
            fprintf('\n SR = %2.2f��  noiseratio = %2.2f\n,',SR,noiseratio);
            pvec = ones(nr,1);
            cnt = round(0.1*nr);
            pvec(1:cnt) = 2*pvec(1:cnt);
            pvec(cnt+[1:cnt]) = 4*pvec(cnt+[1:cnt]);
            pvec = nr*pvec/sum(pvec);
            qvec = ones(nc,1);
            cnt = round(0.1*nc);
            qvec(1:cnt) = 2*qvec(1:cnt);
            qvec(cnt+[1:cnt]) = 4*qvec(cnt+[1:cnt]);
            qvec = nc*qvec/sum(qvec);
            probmatrix = rand(nr,nc).*(pvec*qvec');
            [probvec,sortidx] = sort(probmatrix(:),'descend');
            nzsortidx = find(probvec>= probvec(p));
            nzidx = sortidx(nzsortidx);
            zidx = sortidx(p+1:end);
        end
        
        bb =  Mstar(nzidx);
        
        if strcmp(scenario,'noiseless')
            xi = sparse(p,1);
            sigma = 0;
        else
            randnvec = randn(p,1);
            sigma = noiseratio*norm(bb)/norm(randnvec);
            xi = sigma*randnvec;
            bb = bb + xi;
        end
        
        A = zeros(nr,nc);
        
        A(nzidx) = bb;
        
    %% *************** Initialization part *********************
        mu = 1.0e-8;
            
        FnormA = norm(A,'fro'); 
            
        r = min(min(nr,nc),150);  
      
        pars.normM = normM;
        
        pars.normb = norm(bb);
        
        pars.nc = nc;  pars.nr = nr;
        
        [U,dA,V] = svd(full(A),'econ');
        
        Ustart = U(:,1:r);
        
        Vstart = V(:,1:r);
        
        dA = diag(dA)';
        
        max_dA = max(dA);
            
      %% **************** used for MAPM and ALS *********************      
        dd =  ones(1,r);
            
        UVstart = (Ustart.*dd)*Vstart';
            
        M0 = zeros(nr,nc);
            
        M0(nzidx) = A(nzidx);
            
        M0(zidx) = UVstart(zidx);
               
  %% ********************** AMM_solver ******************************
            
        OPTIONS_AMM.Lip_const = 2.5*max_dA;
  
        lambda = 10*const_AMM*FnormA;
  
        Ustart_AMM = Ustart.*dA(1:r).^(1/2);  
  
        Vstart_AMM = Vstart.*dA(1:r).^(1/2);  
  
        clear U  V  dA;

        OPTIONS_AMM.tol = 1.0e-3;
  
        tstart = clock;
  
        [AMM_Xopt,AMM_rank] = AMM_solver(A,Ustart_AMM,Vstart_AMM,nzidx,OPTIONS_AMM,pars,lambda,mu,r);
            
        AMM_time = etime(clock,tstart);
            
        AMM_relerr = norm(AMM_Xopt- Mstar,'fro')/normM;
      
        AMM_matrank(test_iter,i) = AMM_rank;
            
        AMM_matrelerr(test_iter,i) = AMM_relerr;
            
        AMM_mattime(test_iter,i) =  AMM_time;
        
   %% ********************** Hybrid_solver *************************
                       
        lambda = 10*const_MAPM*FnormA;
            
        OPTIONS_AMM.Lip_const = 2.5*max_dA;
        
        tstart = clock;
        
        [Uinit,Vinit,Brid_rank]= Hybrid_initial(M0,Ustart,Vstart,dd,zidx,nzidx,OPTIONS_MAPM,pars,lambda,mu,r);

        OPTIONS_AMM.tol = 5.0e-3;
        
        Xopt = Hybrid_smooth(A,Uinit,Vinit,nzidx,OPTIONS_AMM,pars,mu);
        
        Brid_time = etime(clock,tstart);
        
        Brid_relerr = norm(Xopt- Mstar,'fro')/normM;
       
        Brid_matrelerr(test_iter,i) = Brid_relerr;
        
        Brid_matrank(test_iter,i) = Brid_rank;
        
        Brid_mattime(test_iter,i) = Brid_time;

     %% ********************** ALS_solver ******************************
            
        lambda = const_ALS*max_dA;
            
        tstart = clock;
        
        [FXopt,Fro_rank] = ALS_solver(M0,Ustart,Vstart,dd,zidx,nzidx,OPTIONS_ALS,lambda,r);
         
        Fro_time = etime(clock,tstart);
        
        Fro_relerr = norm(FXopt- Mstar,'fro')/normM;
        
        ALS_matrelerr(test_iter,i) = Fro_relerr;
        
        ALS_matrank(test_iter,i) = Fro_rank;
        
        ALS_mattime(test_iter,i) = Fro_time;
    
    end
        
        AMM_averelerr(i)= mean(AMM_matrelerr(:,i))
        
        AMM_averank(i)= mean(AMM_matrank(:,i))
        
        AMM_avetime(i)= mean(AMM_mattime(:,i))
        
                
        Brid_averelerr(i) =  mean(Brid_matrelerr(:,i))
        
        Brid_aveRankX(i) =  mean(Brid_matrank(:,i))
        
        Brid_avetime(i) =  mean(Brid_mattime(:,i))
        
        
        ALS_averelerr(i) =  mean(ALS_matrelerr(:,i))
        
        ALS_averank(i) = mean(ALS_matrank(:,i))
        
        ALS_avetime(i) =  mean(ALS_mattime(:,i))
        
end
  
save('AMM_result','AMM_averelerr','AMM_averank','AMM_avetime')

save('Brid_result','Brid_averelerr','Brid_averank','Brid_avetime')

save('ALS_result','ALS_averelerr','ALS_averank','ALS_avetime')

%% *************************************************************************
