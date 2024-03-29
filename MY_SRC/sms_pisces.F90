MODULE sms_pisces   
   !!----------------------------------------------------------------------
   !!                     ***  sms_pisces.F90  ***  
   !! TOP :   PISCES Source Minus Sink variables
   !!----------------------------------------------------------------------
   !! History :   1.0  !  2000-02 (O. Aumont) original code
   !!             3.2  !  2009-04 (C. Ethe & NEMO team) style
   !!----------------------------------------------------------------------
   USE par_oce
   USE par_trc

   IMPLICIT NONE
   PUBLIC

   INTEGER ::   numnatp_ref = -1           !! Logical units for namelist pisces
   INTEGER ::   numnatp_cfg = -1           !! Logical units for namelist pisces
   INTEGER ::   numonp      = -1           !! Logical unit for namelist pisces output

   !                                                       !:  PISCES  : silicon dependant half saturation

   !!* Model used
   LOGICAL  ::  ln_p2z            !: Flag to use LOBSTER model
   LOGICAL  ::  ln_p4z            !: Flag to use PISCES  model
   LOGICAL  ::  ln_p5z            !: Flag to use PISCES  quota model
   LOGICAL  ::  ln_ligand         !: Flag to enable organic ligands
   LOGICAL  ::  ln_sediment       !: Flag to enable sediment module
   LOGICAL  ::  ln_copper         !: Flag to enable copper model
   LOGICAL  ::  ln_zinc           !: Flag to enable zinc model
   LOGICAL  ::  ln_cobalt         !: Flag to enable cobalt model
   LOGICAL  ::  ln_manganese      !: Flag to enable manganese model

   !!*  Time variables
   INTEGER  ::   nrdttrc           !: ???
   REAL(wp) ::   rfact , rfactr    !: ???
   REAL(wp) ::   rfact2, rfact2r   !: ???
   REAL(wp) ::   xstep             !: Time step duration for biology
   REAL(wp) ::   ryyss             !: number of seconds per year 
   REAL(wp) ::   r1_ryyss          !: inverse number of seconds per year 


   !!*  Biological parameters 
   REAL(wp) ::   rno3              !: ???
   REAL(wp) ::   o2ut              !: ???
   REAL(wp) ::   po4r              !: ???
   REAL(wp) ::   rdenit            !: ???
   REAL(wp) ::   rdenita           !: ???
   REAL(wp) ::   o2nit             !: ???
   REAL(wp) ::   wsbio, wsbio2     !: ???
   REAL(wp) ::   wsbio2max         !: ???
   REAL(wp) ::   wsbio2scale       !: ???
   REAL(wp) ::   xkmort            !: ???
   REAL(wp) ::   ferat3            !: ???
   REAL(wp) ::   ldocp             !: ???
   REAL(wp) ::   ldocz             !: ???
   REAL(wp) ::   lthet             !: ???
   REAL(wp) ::   no3rat3           !: ???
   REAL(wp) ::   po4rat3           !: ???
   REAL(wp) ::   curat3            !: ???
   REAL(wp) ::   zcu2c        !: ???
   REAL(wp) ::   znrat3            !: ???
   REAL(wp) ::   znf       !: ???
   LOGICAL  ::  ln_znf
   REAL(wp) ::   zzn2c       !: ???
   REAL(wp) ::   zzn2s       !: ???
   REAL(wp) ::   corat3            !: ???
   REAL(wp) ::   zco2c        !: ???
   REAL(wp) ::   mnrat3            !: ???
   REAL(wp) ::   zmn2c        !: ???


   !!*  diagnostic parameters 
   REAL(wp) ::  tpp                !: total primary production
   REAL(wp) ::  t_oce_co2_exp      !: total carbon export
   REAL(wp) ::  t_oce_co2_flx      !: Total ocean carbon flux
   REAL(wp) ::  t_oce_co2_flx_cum  !: Cumulative Total ocean carbon flux
   REAL(wp) ::  t_atm_co2_flx      !: global mean of atmospheric pco2

   !!* restoring
   LOGICAL  ::  ln_pisdmp          !: restoring or not of nutrients to a mean value
   INTEGER  ::  nn_pisdmp          !: frequency of relaxation or not of nutrients to a mean value

   !!* Mass conservation
   LOGICAL  ::  ln_check_mass      !: Flag to check mass conservation
   LOGICAL , PUBLIC ::   ln_ironice   !: boolean for Fe input from sea ice

   !!*  Biological fluxes for light : variables shared by pisces & lobster
   INTEGER , ALLOCATABLE, SAVE, DIMENSION(:,:)   ::  neln  !: number of T-levels + 1 in the euphotic layer
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:)   ::  heup  !: euphotic layer depth
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::  etot  !: par (photosynthetic available radiation)
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::  etot_ndcy      !: PAR over 24h in case of diurnal cycle
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::  enano, ediat   !: PAR for phyto, nano and diat 
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::  enanom, ediatm !: PAR for phyto, nano and diat 
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::  epico          !: PAR for pico
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::  epicom         !: PAR for pico
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::  emoy           !: averaged PAR in the mixed layer
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:)   ::  heup_01 !: Absolute euphotic layer depth
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:)   ::  xksi  !:  LOBSTER : zooplakton closure

   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:)   ::  pco2s !: surface pco2
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::  co2aq ! Co2 aq

   !!*  Biological fluxes for primary production
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:)    ::   xksimax    !: ???
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   biron      !: bioavailable fraction of iron
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   plig       !: proportion of iron organically complexed
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   bcopper    !: Cam Bioavailable copper
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   bzinc      !:
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   zcofree    !: Free cobal
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   bacbio    !: ??? Implici Necessary with Co model
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   phyrel     !: relativenecessary with Co model
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   zmnfree    !: Free cobal
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   qminmnd  
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   qminmnn
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   qminfed
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   qminfen
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   qminczd
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:)  ::   qminczn

   !!*  Sinking speed
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   wsbio3   !: POC sinking speed 
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   wsbio4   !: GOC sinking speed
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   wsscu
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   wsszn
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   wssco
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   wssmn

   !!*  SMS for the organic matter
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   xfracal    !: ??
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   nitrfac    !: ??
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   nitrfac2   !: ??
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   orem       !: ??
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   xdiss      !: ??
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   prodcal    !: Calcite production
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   prodpoc    !: Calcite production
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   conspoc    !: Calcite production
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   prodgoc    !: Calcite production
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   consgoc    !: Calcite production
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   blim       !: bacterial production factor
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   sizen      !: size of diatoms 
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   sizep      !: size of diatoms 
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   sized      !: size of diatoms 
   !! Growth rate information
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   mu_n      !: growrth rate of nanos
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   mu_d      !: growth rate of diatoms
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   mu_nm      !: light limited growth rate of nanos
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   mu_dm      !: light limited growth rate of diatoms

   !!* Variable for chemistry of the CO2 cycle
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   ak13       !: ???
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   ak23       !: ???
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   aksp       !: ???
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   hi         !: ???
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   excess     !: ???
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   aphscale   !: 


   !!* Temperature dependancy of SMS terms
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   tgfunc    !: Temp. dependancy of various biological rates
   REAL(wp), ALLOCATABLE, SAVE, DIMENSION(:,:,:) ::   tgfunc2   !: Temp. dependancy of mesozooplankton rates

   !!----------------------------------------------------------------------
   !! NEMO/TOP 4.0 , NEMO Consortium (2018)
   !! $Id: sms_pisces.F90 10780 2019-03-20 17:53:44Z aumont $ 
   !! Software governed by the CeCILL license (see ./LICENSE)
   !!----------------------------------------------------------------------
CONTAINS

   INTEGER FUNCTION sms_pisces_alloc()
      !!----------------------------------------------------------------------
      !!        *** ROUTINE sms_pisces_alloc ***
      !!----------------------------------------------------------------------
      USE lib_mpp , ONLY: ctl_stop
      INTEGER ::   ierr(10)        ! Local variables
      !!----------------------------------------------------------------------
      ierr(:) = 0
      !*  Biological fluxes for light : shared variables for pisces & lobster
      ALLOCATE( etot(jpi,jpj,jpk), neln(jpi,jpj), heup(jpi,jpj),    &
        &       heup_01(jpi,jpj) , xksi(jpi,jpj), pco2s(jpi,jpj)    ,  STAT=ierr(1) )
      !
  
      IF( ln_p4z .OR. ln_p5z ) THEN
         !*  Biological fluxes for light 
         ALLOCATE(  enano(jpi,jpj,jpk)    , ediat(jpi,jpj,jpk) ,   &
           &        enanom(jpi,jpj,jpk)   , ediatm(jpi,jpj,jpk),   &
           &        co2aq(jpi,jpj,jpk),   &
           &        etot_ndcy(jpi,jpj,jpk), emoy(jpi,jpj,jpk)  ,  STAT=ierr(2) ) 

         !*  Biological fluxes for primary production
         ALLOCATE( xksimax(jpi,jpj)  , biron(jpi,jpj,jpk)      ,  STAT=ierr(3) )
         !
         !*  SMS for the organic matter
         ALLOCATE( xfracal (jpi,jpj,jpk), orem(jpi,jpj,jpk)    ,    &
            &      nitrfac(jpi,jpj,jpk), nitrfac2(jpi,jpj,jpk) ,    &
            &      prodcal(jpi,jpj,jpk) , xdiss   (jpi,jpj,jpk),    &
            &      prodpoc(jpi,jpj,jpk) , conspoc(jpi,jpj,jpk) ,    &
            &      prodgoc(jpi,jpj,jpk) , consgoc(jpi,jpj,jpk) ,    &
            &      mu_n(jpi,jpj,jpk) , mu_d(jpi,jpj,jpk) ,    &
            &      mu_nm(jpi,jpj,jpk) , mu_dm(jpi,jpj,jpk) ,    &
            &      blim   (jpi,jpj,jpk) , qminfed(jpi,jpj,jpk),qminfen(jpi,jpj,jpk),STAT=ierr(4) )

         !* Variable for chemistry of the CO2 cycle
         ALLOCATE( ak13  (jpi,jpj,jpk) ,                            &
            &      ak23(jpi,jpj,jpk)    , aksp  (jpi,jpj,jpk) ,     &
            &      hi  (jpi,jpj,jpk)    , excess(jpi,jpj,jpk) ,     &
            &      aphscale(jpi,jpj,jpk),                         STAT=ierr(5) )
         !
         !* Temperature dependancy of SMS terms
         ALLOCATE( tgfunc(jpi,jpj,jpk)  , tgfunc2(jpi,jpj,jpk),   STAT=ierr(6) )
         !
         !* Sinkong speed
         ALLOCATE( wsbio3 (jpi,jpj,jpk) , wsbio4 (jpi,jpj,jpk),     &
            &                             STAT=ierr(7) )   
         ! 
         IF( ln_ligand ) THEN
           ALLOCATE( plig(jpi,jpj,jpk)  ,                         STAT=ierr(8) )
         ENDIF
      ENDIF
         IF( ln_copper ) THEN
           ALLOCATE( bcopper(jpi,jpj,jpk) , wsscu(jpi,jpj,jpk)    , STAT=ierr(11) )
         ENDIF

         IF( ln_zinc ) THEN
           ALLOCATE( bzinc(jpi,jpj,jpk) , wsszn(jpi,jpj,jpk)    , STAT=ierr(12) )
         ENDIF
         IF( ln_cobalt ) THEN
           ALLOCATE( bacbio(jpi,jpj,jpk)    , phyrel(jpi,jpj,jpk)    ,  &
           &     zcofree(jpi,jpj,jpk), wssco(jpi,jpj,jpk)       ,   STAT=ierr(13) )
         ENDIF
        IF (ln_manganese) THEN
          ALLOCATE(zmnfree(jpi,jpj,jpk)    , wssmn(jpi,jpj,jpk) ,  STAT=ierr(14) )
          ALLOCATE(qminmnd(jpi,jpj,jpk), qminmnn(jpi,jpj,jpk), qminczd(jpi,jpj,jpk) &
          &        ,qminczn(jpi,jpj,jpk)  ,  STAT=ierr(15) )
        ENDIF
       !
      IF( ln_p5z ) THEN
         !       
         ALLOCATE( epico(jpi,jpj,jpk)   , epicom(jpi,jpj,jpk) ,   STAT=ierr(9) ) 

         !*  Size of phytoplankton cells
         ALLOCATE( sizen(jpi,jpj,jpk), sizep(jpi,jpj,jpk),         &
           &       sized(jpi,jpj,jpk),                            STAT=ierr(10) )
      ENDIF
      !
      sms_pisces_alloc = MAXVAL( ierr )
      !
      IF( sms_pisces_alloc /= 0 )   CALL ctl_stop( 'STOP', 'sms_pisces_alloc: failed to allocate arrays' ) 
      !
   END FUNCTION sms_pisces_alloc

   !!======================================================================   
END MODULE sms_pisces    
