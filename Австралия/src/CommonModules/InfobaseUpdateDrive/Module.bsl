////////////////////////////////////////////////////////////////////////////////
// Infobase update
//
////////////////////////////////////////////////////////////////////////////////

#Region Public

// Fills out basic information about the library or default configuration.
// Library which name matches configuration name in metadata is defined as default configuration.
// 
// Parameters:
//  Definition - Structure - information about the library:
//
//   Name                 - String - name of the library, for example, "StandardSubsystems".
//   Version              - String - version in the format of 4 digits, for example, "2.1.3.1".
//
//   RequiredSubsystems - Array - names of other libraries (String) on which this library depends.
//                                  Update handlers of such libraries should
//                                  be called before update handlers of this library.
//                                  IN case of circular dependencies or, on
//                                  the contrary, absence of any dependencies, call out
//                                  procedure of update handlers is defined by the order of modules addition in
//                                  procedure WhenAddingSubsystems of common module ConfigurationSubsystemsOverridable.
//
Procedure OnAddSubsystem(Definition) Export
	
	Definition.Name		= Metadata.Name;
	Definition.Version	= "1.4.2.14";
	Definition.DeferredHandlerExecutionMode = "Sequentially";
	
EndProcedure

#EndRegion

#Region Internal

// Adds to the list of
// procedures (IB data update handlers) for all supported versions of the library or configuration.
// Appears before the start of IB data update to build up the update plan.
//
// Parameters:
//  Handlers - ValueTable - See description
// of the fields in the procedure InfobaseUpdate.NewUpdateHandlerTable
//
// Example of adding the procedure-processor to the list:
//  Handler = Handlers.Add();
//  Handler.Version              = "1.0.0.0";
//  Handler.Procedure           = "IBUpdate.SwitchToVersion_1_0_0_0";
//  Handler.ExclusiveMode    = False;
//  Handler.Optional        = True;
// 
Procedure OnAddUpdateHandlers(Handlers) Export

#Region FirstLaunch
	
	Handler = Handlers.Add();
	Handler.Version	        = "";
	Handler.InitialFilling  = True;
	Handler.ExecutionMode   = "Exclusive";
	Handler.Procedure       = "InfobaseUpdateDrive.FirstLaunch";
	Handler.ObjectsToRead   = "";
	Handler.ObjectsToChange = "";
	Handler.Comment = "";
	
#EndRegion

#Region Version_1_4_1
	
	// begin Drive.FullVersion
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.1";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.Inventory.ClearBatchesInWIPRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.ManufacturingOperation.FillInventoryStructuralUnitPosition";
	
	// end Drive.FullVersion
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.InventoryTransfer.ChangeInventoryRecordsForChargeToExpenses";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.Inventory.FillCurrencyInIntraTransferRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.InventoryCostLayer.FillCurrencyInIntraTransferRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.AccountsPayable.CheckAndCorrectAmountsForPayment";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.AccountsReceivable.CheckAndCorrectAmountsForPayment";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.InventoryWriteOff.ClearIncomeAndExpensesRecordsForMOHExpenseItem";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.3";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.PaymentExpense.FillPaymentDetailsInfobaseUpdate";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.3";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.PaymentReceipt.FillPaymentDetailsInfobaseUpdate";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.3";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.Inventory.FillEmptyAttributesInRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.3";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.InventoryCostLayer.FillEmptyAttributesInRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.3";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.WorkOrder.RefillSalesRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.3";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.InventoryTransfer.FillSalesRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.4";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.DebitNote.RefillGoodsInvoicedNotReceivedRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.4";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.BusinessUnits.FillRequiredAttributes";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.4";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.PlanningPeriods.FillRequiredAttributes";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.5";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.Projects.FillDurationUnit";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.6";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.DebitNote.SetRegisterIncome";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.6";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.DebitNote.PostIncomeAndExpensesRegister";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.7";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.PaymentExpense.SetFeeBusinessLine";

	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.7";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.PaymentReceipt.SetFeeBusinessLine";

	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.8";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.Inventory.FillCorrInventoryAccountType";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.9";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.IncomeAndExpenseItems.FillPredefinedDataProperties";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.9";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.IncomeAndExpenseTypes.FillPredefinedDataProperties";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.9";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Constants.AccountingModuleSettings.UpdatePredefinedAccountingSettings";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.9";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "InfobaseUpdateDrive.UpdateAdditionalInformation";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.1.9";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "MonitoringCenterInternal.FillDefaultSendServiceParameters";
	
#EndRegion

#Region Version_1_4_2
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.1";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.Companies.FillPricesPrecision";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.KitOrder.FillSalesOrderInTabularSections";
	
	// begin Drive.FullVersion
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.ProductionOrder.FillSalesOrderInTabularSections";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.InventoryDemand.UpdateProductionDocumentData";
	
	// end Drive.FullVersion

	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.2";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.PurchaseOrder.FillSalesOrderPosition";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.3";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.QuotationStatuses.UpdateStatusConverted";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.3";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.Quote.UpdateQuotationStatus";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.3";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.LoanInterestCommissionAccruals.UpdateDocumentTabSectionAnalytics";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.4";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.CreditNote.NotTaxableVATOutputRecords";
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.5";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.EarningsCalculationParameters.ChangeSalesAmountForResponsibleParameter";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.6";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.CashVoucher.FillInEmployeeGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.6";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.PaymentExpense.FillInEmployeeGLAccounts";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.6";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "InfobaseUpdateDrive.ReplaceDeletedRolesInAccessGroupProfiles";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.7";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.ShippingAddresses.ConvertCounterpartiesToShippingAddresses";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.8";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.LoanContract.FillEmptyCostAccountCommission";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.9";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.AccountSalesFromConsignee.FillDocumentTax";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.9";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.AccountSalesToConsignor.FillDocumentTax";
	
	// begin Drive.FullVersion
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.10";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.ManufacturingOperation.FillWorkInProgressStatementRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.10";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Documents.SubcontractorOrderIssued.FillWorkInProgressStatementRecords";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.10";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.ProductionComponents.FillRecords";

	// end Drive.FullVersion
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.11";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.AccountingEntriesTemplates.RenameDataSource";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.11";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.AccountingTransactionsTemplates.RenameDataSource";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.12";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "AccumulationRegisters.Inventory.FillSourceDocumentInSIRRecords";
	
	// begin Drive.FullVersion
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.12";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "InfobaseUpdateDrive.ReplaceDeletedRolesInProductionAccessGroupProfiles";
	
	// end Drive.FullVersion
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.13";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.BusinessUnits.ClearRequiredAttributes";
	
	Handler = Handlers.Add();
	Handler.Version			= "1.4.2.14";
	Handler.InitialFilling	= False;
	Handler.ExecutionMode	= "Exclusive";
	Handler.Procedure		= "Catalogs.AccessGroupProfiles.ClearRemovedRoles";

#EndRegion

EndProcedure

// Called before the procedures-handlers of IB data update.
//
Procedure BeforeUpdateInfobase() Export
	
	
	
EndProcedure

// Called after the completion of IB data update.
//		
// Parameters:
//   PreviousVersion       - String - version before update. 0.0.0.0 for an empty IB.
//   CurrentVersion          - String - version after update.
//   ExecutedHandlers - ValueTree - list of completed
//                                             update procedures-handlers grouped by version number.
//   PutReleaseNotes - Boolean - (return value) if
//                                you set True, then form with events description will be output. By default True.
//   ExclusiveMode           - Boolean - True if the update was executed in the exclusive mode.
//		
// Example of bypass of executed update handlers:
//		
// For Each Version From ExecutedHandlers.Rows Cycle
//		
// 	If Version.Version =
// 		 * Then Ha//ndler that can be run every time the version changes.
// 	Otherwise,
// 		 Handler runs for a definite version.
// 	EndIf;
//		
// 	For Each Handler From Version.Rows
// 		Cycle ...
// 	EndDo;
//		
// EndDo;
//
Procedure AfterUpdateInfobase(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, PutReleaseNotes, ExclusiveMode) Export
	
	SetUpdateConfigurationPackage();
	
EndProcedure

// Vihzihvaetsja pri podgotovke tablichnogo dokumenta s opisaniem izmeneniy sistemih.
//
// Parameters:
//   Maket - TablichnihyDokument - opisanie obnovleniy.
//
// See also common ApplicationReleaseNotes layout.
//
Procedure OnPrepareUpdateDetailsTemplate(Val Template) Export
	
	
	
EndProcedure

// Overrides infobase data update mode.
// Used in rare (abnormal) migration scenarios that cannot be done in the standard update mode 
// determination procedure.
//
// Parameters:
//   RezhimObnovlenijaDannihkh - Stroka - v obrabotchike mozhno prisvoitjh odno iz znacheniy:
//              "InitialFilling" if this is the first start of an empty infobase (data area).
//              "VersionUpdate" if this is the first start after an infobase configuration update.
//              "MigrationFromAnotherApplication" if this is the first start after infobase 
//                                          configuration update that changed the infobase configuration name.
//
//   StandartnajaObrabotka  - Bulevo - esli prisvoitjh Lozhjh, to standartnaja procedura 
//                                    opredelenija rezhima obnovlenija ne vihpolnjaetsja, a 
//                                    ispoljhzuetsja znachenie RezhimObnovlenijaDannihkh.
//
Procedure OnDefineDataUpdateMode(DataUpdateMode, StandardProcessing) Export
	
	
	
EndProcedure

// Adds application migration handlers to the list.
// For example, to migrate between a different applications of the same family: Base -> Standard > CORP
// The procedure is called prior to infobase data update.
//
// Parameters:
//	Obrabotchiki - TablicaZnacheniy - s kolonkami:
//		* PredihdujsheeImjaKonfiguracii - Stroka - imja konfiguracii, s kotoroy vihpolnjaetsja perekhod;
//			ili "*", esli nuzhno vihpolnjatjh pri perekhode s ljuboy konfiguracii.
//		* Procedura - Stroka - polnoe imja procedurih-obrabotchika perekhoda s programmih PredihdujsheeImjaKonfiguracii. 
//			Naprimer, "ObnovlenieInformacionnoyBazihUPP.ZapolnitjhUchetnujuPolitiku"
//			Objazateljhno dolzhna bihtjh ehksportnoy.
//
// Example:
//	Obrabotchik = Obrabotchiki.Dobavitjh();
//	Obrabotchik.PredihdujsheeImjaKonfiguracii  = "UpravlenieTorgovley";
//	Obrabotchik.Procedura                  = "ObnovlenieInformacionnoyBazihUPP.ZapolnitjhUchetnujuPolitiku";
//
Procedure OnAddApplicationMigrationHandlers(Handlers) Export
	
	
	
EndProcedure

// Called when all the application migration handlers have been executed but before the infobase 
// data update.
//
// Parameters:
//  PredihdujsheeImjaKonfiguracii    - Stroka - imja konfiguracii do perekhoda.
//  PredihdujshajaVersijaKonfiguracii - Stroka - imja predihdujshey konfiguracii (do perekhoda).
//  Parametrih                    - Struktura - 
//    * VihpolnitjhObnovlenieSVersii   - Bulevo - po umolchaniju Istina. If False, only mandatory 
//        update handlers (with version "*") are executed.
//    * VersijaKonfiguracii           - Stroka - nomer versii posle perekhoda. 
//        By default, it is equal to the version in configuration metadata properties.
//        To execute, for example, all migration from PreviousConfigurationVersion handlers, set the 
//        PreviousConfigurationVersion parameter.
//        To perform all update handlers, set the value to "0.0.0.1".
//    * OchistitjhSvedenijaOPredihdujsheyKonfiguracii - Bulevo - po umolchaniju Istina. 
//        When the previous configuration has the same name with one of current configuration subsystems, set the parameter to False.
//
Procedure OnCompleteApplicationMigration(Val PreviousConfigurationName, 
	Val PreviousConfigurationVersion, Parameters) Export
	
	
	
EndProcedure

#Region ConfigurationPackage

#Region FirstLaunchHandlers

// Procedure fills in empty IB.
//
Procedure FirstLaunch() Export
	
	CurrentSessionDate = CurrentSessionDate();
	
	BeginTransaction();
	
	// Fill the Calendar under BusinessCalendar.
	Calendar = DriveServer.GetFiveDaysCalendar();// Will be removed - 567
	If Calendar = Undefined Then
		
		CreateFiveDaysCalendar();
		Calendar = DriveServer.GetFiveDaysCalendar(); 
		
	EndIf;
	
	FillFilterUserSettings();
	
	// Fill in company kind
	MainCompany = Catalogs.Companies.MainCompany.GetObject();
	MainCompany.LegalEntityIndividual = Enums.CounterpartyType.LegalEntity;
	
	WriteCatalogObject(MainCompany);
	
	// Fill in structural units
	MainDepartment = Catalogs.BusinessUnits.MainDepartment.GetObject();
	MainDepartment.Company				= Catalogs.Companies.MainCompany;
	MainDepartment.StructuralUnitType	= Enums.BusinessUnitsTypes.Department;
	
	WriteCatalogObject(MainDepartment);
	
	DriveServer.SetUserSetting(MainDepartment.Ref, "MainDepartment");
	
	MainWarehouse = Catalogs.BusinessUnits.MainWarehouse.GetObject();
	MainWarehouse.Company				= Catalogs.Companies.MainCompany;
	MainWarehouse.StructuralUnitType	= Enums.BusinessUnitsTypes.Warehouse;
	
	WriteCatalogObject(MainWarehouse);
	
	DriveServer.SetUserSetting(MainWarehouse.Ref, "MainWarehouse");
	
	Constants.PlannedTotalsOptimizationDate.Set(EndOfMonth(AddMonth(CurrentSessionDate, 1)));
	
	ContactsManager.SetPropertiesPredefinedContactInformationTypes();
	
	// Fill in contracts forms.
	FillContractsForms();

	EquipmentManagerServerCallOverridable.RefreshSuppliedDrivers();
	
	Constants.UseDefaultTypeOfAccounting.Set(True);
	Constants.UseFIFO.Set(True);
	Constants.UseWorkOrderStatuses.Set(True);
	Catalogs.DuplicateRules.SetPredefinedDuplicateRules();
	Constants.UseBarcodesInPrintForms.Set(True);
	Constants.UseAdditionalAttributesAndInfo.Set(True);
	Catalogs.QuotationStatuses.SetPredefinedQuotationStatus();
	BusinessProcesses.PurchaseApproval.InitializePerformerRoles();
	ExchangePlans.Website.InitializePerformerRoles();
	
	FillPredefinedPeripheralsDrivers();
	
	Catalogs.IncomeAndExpenseTypes.FillPredefinedDataProperties();
	Catalogs.IncomeAndExpenseItems.FillPredefinedDataProperties();
	Constants.AccountingModuleSettings.FillPredefinedDataProperties();
	
	// begin Drive.FullVersion
	
	// Production planning
	Catalogs.ProductionOrdersPriorities.FillPredefinedProductionOrdersPriorities();
	Catalogs.TimeUOM.FillPredefinedTimeUOM();
	
	SetUseByProductsAccountingStartingDate();
	
	// end Drive.FullVersion

	SetNeedKitProcessingInfobaseUpdate();
	
	Try
		
		CommitTransaction();
		
	Except
		
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error first launch : %2'; ru = 'Ошибка при первом запуске : %2';pl = 'Błąd pierwszego uruchomienia: %2';es_ES = 'Error del primer lanzamiento:%2';es_CO = 'Error del primer lanzamiento:%2';tr = 'İlk başlatma hatası : %2';it = 'Errore primo avvio: %2';de = 'Fehler Erster Start: %2'"),
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			NStr("en = 'First launch'; ru = 'Первый запуск';pl = 'Pierwsze uruchomienie';es_ES = 'Primer lanzamiento';es_CO = 'Primer lanzamiento';tr = 'İlk başlatma';it = 'Primo avvio';de = 'Erster Start'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorDescription);
			
	EndTry;
	
EndProcedure

#EndRegion

#Region BackgroundJobsProcedures

Procedure ExecuteFillByDefault(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	JobResult = JobResult();
	
	FillDataByDefaultFirstLaunch(JobResult);
	
	PutToTempStorage(JobResult, BackgroundJobStorageAddress); 
	
EndProcedure

Procedure ExecuteLoadCountriesFromFirstLaunch(JobParameters, StorageAddress = "") Export
	
	JobResult = JobResult();
	JobResult.Insert("Countries", Undefined);
	
	Try
		JobResult.Countries = LoadCountriesFromFirstLaunch(JobParameters);
	Except
		JobResult.Done = False;
		JobResult.ErrorMessage = BriefErrorDescription(ErrorInfo());
	EndTry;
	
	PutToTempStorage(JobResult, StorageAddress);
	
EndProcedure

Procedure ExecuteFillPredefinedData(Parameters, BackgroundJobStorageAddress = "") Export
	
	JobResult = JobResult();
	
	BasePath	= "";
	FullPath	= Parameters.FullPath;
	
	If Parameters.Property("ZIP") Then
		
		ZIPFile = Parameters.ZIP;
	
		TemporaryFolderToUnpacking = GetTempFileName("");
		TemporaryZIPFile = GetTempFileName("zip"); 
		
		ZIPFile.Write(TemporaryZIPFile);
		
		Archive = New ZipFileReader();
		Archive.Open(TemporaryZIPFile);
		Archive.ExtractAll(TemporaryFolderToUnpacking, ZIPRestoreFilePathsMode.Restore);
		Archive.Close();
		
		BasePath = TemporaryFolderToUnpacking + "\";
		FullPath = BasePath + FullPath + "\data.xml";
		
	EndIf;
	
	UpdateConfigurationPackage = False;
	If Parameters.Property("UpdateConfigurationPackage") Then
		UpdateConfigurationPackage = Parameters.UpdateConfigurationPackage;
	EndIf;
	
	Try
		FillPredefinedData(FullPath, BasePath, UpdateConfigurationPackage, JobResult);
		RunExtensionUpdateHandlers();
	Except
		JobResult.Done			= False;
		JobResult.ErrorMessage	= BriefErrorDescription(ErrorInfo());
	EndTry;
	
	PutToTempStorage(JobResult, BackgroundJobStorageAddress);
	
EndProcedure

Procedure ExecuteUpdateExtensions(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	ResultStructure = New Structure("Done, ErrorMessage", True, "");
	
	Try
		LoadExtensions(ParametersStructure, ResultStructure);
	Except
		ResultStructure.Done			= False;
		ResultStructure.ErrorMessage	= BriefErrorDescription(ErrorInfo());
	EndTry;
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);
	
	
EndProcedure

Procedure ExecuteClearGlAccountsInRecords(ParametersStructure, BackgroundJobStorageAddress = "") Export

	SetPrivilegedMode(True);
	
	RequiredTypeDescription = New TypeDescription("ChartOfAccountsRef.PrimaryChartOfAccounts");
	
	Template = "SELECT DISTINCT
	|	%RegisterName%.Recorder,
	|	""%RegisterName%"" AS RegisterName,
	|	""%RegisterType%"" AS RegisterType
	|FROM
	|	%RegisterType%.%RegisterName% AS %RegisterName%";
	
	QueryText = "";
	
	AccumulationRegisterSearchAreas = New Array;
	AccumulationRegisterSearchAreas.Add("Dimensions");
	AccumulationRegisterSearchAreas.Add("Attributes");
	
	InformationRegisterSearchAreas = New Array;
	InformationRegisterSearchAreas.Add("Dimensions");
	InformationRegisterSearchAreas.Add("Resources");
	InformationRegisterSearchAreas.Add("Attributes");
	
	SearchSettings = New Map;
	SearchSettings.Insert("AccumulationRegisters", New Structure("Areas, RegisterType, CheckMode", AccumulationRegisterSearchAreas, "AccumulationRegister", False));
	SearchSettings.Insert("InformationRegisters", New Structure("Areas, RegisterType, CheckMode", InformationRegisterSearchAreas, "InformationRegister", True));
	
	RegisterFieldMap = New Map;
	For Each Setting In SearchSettings Do
		RegisterMetadataType = Setting.Key;
		SearchAreas = Setting.Value.Areas;
		RegisterType = Setting.Value.RegisterType;
		CheckMode = Setting.Value.CheckMode;
		For Each Register In Metadata[RegisterMetadataType] Do
			If CheckMode And Not Register.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
				Continue;
			EndIf;
			Fields = New Array;
			For Each AreaName In SearchAreas Do
				For Each Area In Register[AreaName] Do
					If Area.Type = RequiredTypeDescription Then
						Fields.Add(Area.Name);
					EndIf;
				EndDo;
			EndDo;
			If Fields.Count() > 0 Then
				If Not IsBlankString(QueryText) Then
					QueryText = QueryText + Chars.LF + ";" + Chars.LF;
				EndIf;
				QueryItem = StrReplace(Template, "%RegisterName%", Register.Name);
				QueryItem = StrReplace(QueryItem, "%RegisterType%", RegisterType);
				QueryText = QueryText + QueryItem;
				RegisterFieldMap.Insert(RegisterFieldMap.Count(), Fields);
			EndIf;
		EndDo;
	EndDo;
	
	// clear DocumentAccountingEntriesStatuses and AccountingJournalEntries
	AccountingQueryText = "";
	QueryItem = StrReplace(Template, "%RegisterName%", "DocumentAccountingEntriesStatuses");
	QueryItem = StrReplace(QueryItem, "%RegisterType%", "InformationRegister");
	AccountingQueryText = AccountingQueryText + QueryItem;
	
	AccountingQueryText = AccountingQueryText + Chars.LF + ";" + Chars.LF;
	QueryItem = StrReplace(Template, "%RegisterName%", "AccountingJournalEntries");
	QueryItem = StrReplace(QueryItem, "%RegisterType%", "AccountingRegister");
	AccountingQueryText = AccountingQueryText + QueryItem;
	
	// clear CashBudget
	CashBudgetQueryText = StrReplace(Template, "%RegisterName%", "CashBudget");
	CashBudgetQueryText = StrReplace(CashBudgetQueryText, "%RegisterType%", "AccumulationRegister");
	
	// clear ProfitEstimation
	ProfitEstimationQueryText = 
	"SELECT
	|	SalesOrderEstimate.Ref AS Ref,
	|	SalesOrderEstimate.LineNumber AS LineNumber,
	|	SalesOrderEstimate.Products AS Products
	|FROM
	|	Document.SalesOrder.Estimate AS SalesOrderEstimate
	|WHERE
	|	SalesOrderEstimate.Products REFS ChartOfAccounts.PrimaryChartOfAccounts
	|TOTALS BY
	|	Ref";
	
	If Not IsBlankString(QueryText) Then
			
		Query = New Query;
		Query.Text = QueryText;
		QueryBatch = Query.ExecuteBatch();
		
	EndIf;
	
	AccountingQuery = New Query;
	AccountingQuery.Text = AccountingQueryText;
	AccountingQueryBatch = AccountingQuery.ExecuteBatch();
	
	CashBudgetQuery = New Query;
	CashBudgetQuery.Text = CashBudgetQueryText;
	CashBudgetQueryResult = CashBudgetQuery.Execute();
	
	ProfitEstimationQuery = New Query;
	ProfitEstimationQuery.Text = ProfitEstimationQueryText;
	ProfitEstimationQueryResult = ProfitEstimationQuery.Execute();
		
	BeginTransaction();
	Try
		If Not IsBlankString(QueryText) Then
			For Index = 0 To QueryBatch.Count() - 1 Do
				Selection = QueryBatch[Index].Select();
				While Selection.Next() Do
					If Selection.RegisterType = "AccumulationRegister" Then
						RecordSet = AccumulationRegisters[Selection.RegisterName].CreateRecordSet();
					ElsIf Selection.RegisterType = "AccountingRegister" Then
						RecordSet = AccountingRegisters[Selection.RegisterName].CreateRecordSet();
					Else
						RecordSet = InformationRegisters[Selection.RegisterName].CreateRecordSet();
					EndIf;
					RecordSet.Filter.Recorder.Set(Selection.Recorder);
					RecordSet.Read();
					For Each Record In RecordSet Do
						For Each Field In RegisterFieldMap.Get(Index) Do
							Record[Field] = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
						EndDo;
					EndDo;
					InfobaseUpdate.WriteRecordSet(RecordSet);
				EndDo
			EndDo;
		EndIf;
		
		For Index = 0 To AccountingQueryBatch.Count() - 1 Do
			Selection = AccountingQueryBatch[Index].Select();
			While Selection.Next() Do
				If Selection.RegisterType = "AccountingRegister" Then
					RecordSet = AccountingRegisters[Selection.RegisterName].CreateRecordSet();
				Else
					RecordSet = InformationRegisters[Selection.RegisterName].CreateRecordSet();
				EndIf;
				RecordSet.Filter.Recorder.Set(Selection.Recorder);
				InfobaseUpdate.WriteRecordSet(RecordSet);
			EndDo
		EndDo;
		
		If Not CashBudgetQueryResult.IsEmpty() Then
			Selection = CashBudgetQueryResult.Select();
			While Selection.Next() Do
				RecordSet = AccumulationRegisters.CashBudget.CreateRecordSet();
				RecordSet.Filter.Recorder.Set(Selection.Recorder);
				InfobaseUpdate.WriteRecordSet(RecordSet);
			EndDo
		EndIf;
		
		If Not ProfitEstimationQueryResult.IsEmpty() Then
			
			SelectionRef = ProfitEstimationQueryResult.Select(QueryResultIteration.ByGroups);
			While SelectionRef.Next() Do
				
				DocumentObject = SelectionRef.Ref.GetObject();
				Selection = SelectionRef.Select();
				
				While Selection.Next() Do
					FilterStructure = New Structure("GLAccount", Selection.Products);
					SliceLastTable = InformationRegisters.MappingGLAccountsToIncomeAndExpenseItems.SliceLast(, FilterStructure);
					
					If SliceLastTable.Count() > 0 Then 
						DocumentObject.Estimate[Selection.LineNumber - 1].Products = SliceLastTable[0].IncomeAndExpenseItem;
					EndIf;
				EndDo;
				
				InfobaseUpdate.WriteObject(DocumentObject);
			EndDo
		EndIf;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t add records to a register with GL accounts. Details: %1.'; ru = 'Не удалось добавить записи в регистр со счетами учета. Подробнее: %1.';pl = 'Nie udało się dodać wpisów do rejestru z kontami księgowymi. Szczegóły: %1.';es_ES = 'No se pudo añadir registros a un registro con cuentas del libro mayor. Detalles: %1.';es_CO = 'No se pudo añadir registros a un registro con cuentas del libro mayor. Detalles: %1.';tr = 'Muhasebe hesaplarının olduğu kayda kayıt eklenemedi. Ayrıntılar: %1.';it = 'Impossibile aggiungere registrazioni al registro con conto mastro. Dettagli: %1.';de = 'Fehler beim Hinzufügen von Einträgen zum Register mit Hauptbuch-Konten. Details: %1.'"),
			ErrorDescription());
		Raise ErrorDescription;
	EndTry;

EndProcedure

Procedure ExecuteRefreshReportsOptions(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	Settings = New Structure;
	Settings.Insert("Configuration", 	True);
	Settings.Insert("Extensions", 		False);
	Settings.Insert("SharedData", 		True);
	Settings.Insert("SeparatedData", 	True);
	Settings.Insert("Nonexclusive", 	True);
	Settings.Insert("Deferred", 		True);
	Settings.Insert("Full", 			True);
	
	SetPrivilegedMode(True);
	
	ReportsOptions.Refresh(Settings);
	
	SetPrivilegedMode(False);
	
EndProcedure

#EndRegion

#Region ExportServiceProceduresAndFunctions

// Procedure creates a work schedule based on the business calendar the "Five-day working week" template
// 
Procedure CreateFiveDaysCalendar() Export
	
	BusinessCalendar = CalendarSchedules.MainBusinessCalendar();
	If BusinessCalendar = Undefined Then 
		Return;
	EndIf;
	
	If Not Catalogs.Calendars.FindByAttribute("BusinessCalendar", BusinessCalendar).IsEmpty() Then
		Return;
	EndIf;
	
	NewWorkSchedule = Catalogs.Calendars.CreateItem();
	NewWorkSchedule.Description = Common.ObjectAttributeValue(BusinessCalendar, "Description");
	NewWorkSchedule.BusinessCalendar = BusinessCalendar;
	NewWorkSchedule.FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
	NewWorkSchedule.StartDate = BegOfYear(CurrentSessionDate());
	NewWorkSchedule.ConsiderHolidays = False;
	
	// Fill in week cycle as five-day working week
	For DayNumber = 1 To 7 Do
		NewRow = NewWorkSchedule.FillingTemplate.Add();
		NewRow.DayAddedToSchedule = (DayNumber <= 5);
	EndDo;
	
	InfobaseUpdate.WriteData(NewWorkSchedule, True, True);
	
EndProcedure

// Procedure fills in the passed object catalog and outputs message.
// It is intended to invoke from procedures of filling and processing the infobase directories.
//
// Parameters:
//  CatalogObject - an object that required record.
//
Procedure WriteCatalogObject(CatalogObject, Inform = False)

	If Not CatalogObject.Modified() Then
		Return;
	EndIf;

	If CatalogObject.IsNew() Then
		If CatalogObject.IsFolder Then
			MessageStr = NStr("en = 'Group of catalog ""%1"" is created, code: ""%2"", name: ""%3""'; ru = 'Создана группа справочника ""%1"", код: ""%2"", наименование: ""%3""';pl = 'Została utworzona grupa katalogu ""%1"", kod: %2, nazwa: ""%3""';es_ES = 'Grupo del catálogo ""%1"" se ha creado, código: ""%2"", nombre: ""%3""';es_CO = 'Grupo del catálogo ""%1"" se ha creado, código: ""%2"", nombre: ""%3""';tr = 'Katalog ""%1"" oluşturuldu, kod: ""%2"", isim: ""%3""';it = 'Il gruppo di anagrafiche ""%1"" è stato creato, codice: ""%2"", nome: ""%3""';de = 'Gruppe des Verzeichnisses ""%1"" wird erstellt, Code: ""%2"", Name: ""%3""'") ;
		Else
			MessageStr = NStr("en = 'Item of catalog ""%1"" is created, code: ""%2"", name: ""%3""'; ru = 'Создан элемент справочника ""%1"", код: ""%2"", наименование: ""%3""';pl = 'Został utworzony element katalogu ""%1"", kod: ""%2"", nazwa: ""%3""';es_ES = 'Artículo del catálogo ""%1"" se ha creado, código: ""%2"", nombre: ""%3""';es_CO = 'Artículo del catálogo ""%1"" se ha creado, código: ""%2"", nombre: ""%3""';tr = '""%1"" Kataloğu oluşturuldu, kod: ""%2"", isim: ""%3""';it = 'L''elemento dell''anagrafica ""%1"" è stato creato, codice: ""%2"", nome: ""%3""';de = 'Artikel des Verzeichnisses ""%1"" wird erstellt, Code: ""%2"", Name: ""%3""'") ;
		EndIf; 
	Else
		If CatalogObject.IsFolder Then
			MessageStr = NStr("en = 'Catalog group ""%1"" is processed, code: ""%2"", name: ""%3""'; ru = 'Обработана группа справочника ""%1"", код: ""%2"", наименование: ""%3""';pl = 'Grupa katalogu ""%1"" została przetworzona, kod: ""%2"", nazwa: ""%3""';es_ES = 'Grupo del catálogo ""%1"" se ha procesado, código: ""%2"", nombre: ""%3""';es_CO = 'Grupo del catálogo ""%1"" se ha procesado, código: ""%2"", nombre: ""%3""';tr = '""%1"" katalog grubu işlenir, kod: ""%2"", isim: ""%3""';it = 'Il gruppo anagrafica ""%1"" è stato elaborato, codice: ""%2"", nome: ""%3""';de = 'Verzeichnisgruppe ""%1"" wird verarbeitet, Code: ""%2"", Name: ""%3""'") ;
		Else
			MessageStr = NStr("en = 'Catalog item ""%1"" is processed, code: ""%2"", name: ""%3""'; ru = 'Обработан элемент справочника ""%1"", код: ""%2"", наименование: ""%3""';pl = 'Element katalogu ""%1"" został przetworzony, kod: ""%2"", nazwa: ""%3""';es_ES = 'Artículo del catálogo ""%1"" se ha procesado, código: ""%2"", nombre: ""%3""';es_CO = 'Artículo del catálogo ""%1"" se ha procesado, código: ""%2"", nombre: ""%3""';tr = 'Katalog öğesi ""%1"" işlenir, kod: %2"", isim: ""%3""';it = 'L''elemento del catalogo ""%1"" è stato elaborato, codice: ""%2"", nome: ""%3""';de = 'Verzeichnisartikel ""%1"" wird verarbeitet, Code: ""%2"", Name: ""%3""'") ;
		EndIf; 
	EndIf;

	If CatalogObject.Metadata().CodeLength > 0 Then
		FullCode = CatalogObject.FullCode();
	Else
		FullCode = NStr("en = '<without code>'; ru = '<без кода>';pl = '<bez kodu>';es_ES = '<sin código>';es_CO = '<without code>';tr = '<kodsuz>';it = '<senza codice>';de = '<ohne code>'");
	EndIf; 
	MessageStr = StringFunctionsClientServer.SubstituteParametersToString(MessageStr, CatalogObject.Metadata().Synonym, FullCode, CatalogObject.Description);

	Try
		CatalogObject.Write();
		If Inform = True Then
			CommonClientServer.MessageToUser(MessageStr, CatalogObject);
		EndIf;

	Except

		MessageText = NStr("en = 'Cannot finish action: %1'; ru = 'Не удалось завершить действие: %1';pl = 'Nie można zakończyć działania: %1';es_ES = 'No se puede terminar la acción: %1';es_CO = 'No se puede terminar la acción: %1';tr = 'Eylem tamamlanamaz:%1';it = 'Non è possibile finire l''azione: %1';de = 'Aktion kann nicht beendet werden: %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, MessageStr);

		CommonClientServer.MessageToUser(MessageText);

		ErrorDescription = ErrorInfo();
		WriteLogEvent(MessageText, EventLogLevel.Error,,, ErrorDescription.Definition);

	EndTry;

EndProcedure

#EndRegion

#EndRegion

#EndRegion

#Region Private

#Region DefaultConfigurationPackage

Procedure FillDataByDefaultFirstLaunch(ResultStructure)
	
	TemporaryDirectoryToUnpacking = GetTempFileName("") + "\";
	Path = TemporaryDirectoryToUnpacking + "default\";
	CreateDirectory(Path);
	
	WriteTemplateToDisk(Path, "data.xml", "DefaultDataXML");
	WriteTemplateToDisk(Path, "order_statuses.xml", "DefaultOrderStatuses");
	WriteTemplateToDisk(Path, "default_gl_accounts.xml", "DefaultGLAccounts");
	WriteTemplateToDisk(Path, "default_accounts.xml", "DefaultAccounts");
	WriteTemplateToDisk(Path, "financial_statements.xml", "FinancialStatements");
	
	DataXMLFilePath = Path + "data.xml";
	
	UpdateConfiguration = Constants.FirstLaunchPassed.Get();
	
	FillPredefinedData(DataXMLFilePath, TemporaryDirectoryToUnpacking, UpdateConfiguration, ResultStructure, False);
	
EndProcedure

Procedure WriteTemplateToDisk(Path, FileName, TemplateName)
	
	Template = DataProcessors.FirstLaunch.GetTemplate(TemplateName);
	Template.Write(Path + FileName);
	
EndProcedure

#EndRegion

#Region ConfigurationPackage

#Region Countries

Function LoadCountriesFromFirstLaunch(Parameters)
	
	ZIPFile = Parameters.ZIP;
	
	TemporaryFolderToUnpacking = GetTempFileName("");
	TemporaryZIPFile = GetTempFileName("zip");
	
	ZIPFile.Write(TemporaryZIPFile);

	Archive = New ZipFileReader();
	Archive.Open(TemporaryZIPFile);
	Archive.ExtractAll(TemporaryFolderToUnpacking, ZIPRestoreFilePathsMode.Restore);
	Archive.Close();
	
	Countries = GetCountries(TemporaryFolderToUnpacking);
	
	Return Countries;
	
EndFunction

Function GetCountries(PathToTemporaryFolder)
	
	Countries = New Array();
	
	PathToFile = PathToTemporaryFolder + "\countries.xml";
	If Not FileExist(PathToFile) Then
		Return Countries;
	EndIf;
	
	DOMDocument = DOMDocument(PathToFile);
	Resolver = DOMDocument.CreateNSResolver();
	XPathResult = DOMDocument.EvaluateXPathExpression("//xmlns:country", DOMDocument, Resolver);
	DOMElement = XPathResult.IterateNext();
	
	While DOMElement <> Undefined Do
		
		Country = New Structure();
		For Each Node In DOMElement.ChildNodes Do
			Country.Insert(Node.NodeName, Node.TextContent);
		EndDo;
		
		PathToCountryFile = PathToTemporaryFolder + "\" + Country.Folder;
		If FileExist(PathToCountryFile) Then
			Countries.Add(Country);
		EndIf;
		
		DOMElement = XPathResult.IterateNext();
	EndDo;
	
	Return Countries;
EndFunction

#EndRegion

#Region Extesions

Function LoadExtensionsFromFiles(ProcedureParameters) Export
	
	ResultStructure = New Structure("Done, ErrorMessage", False, "");
	
	If ProcedureParameters.Property("ZIP") Then
		
		ZIPFile = ProcedureParameters.ZIP;
		BasePath	= "";
		FullPath	= ProcedureParameters.FullPath;
		
		TemporaryFolderToUnpacking = GetTempFileName("");
		TemporaryZIPFile = GetTempFileName("zip");
		
		ZIPFile.Write(TemporaryZIPFile);
		
		Archive = New ZipFileReader();
		Archive.Open(TemporaryZIPFile);
		Archive.ExtractAll(TemporaryFolderToUnpacking, ZIPRestoreFilePathsMode.Restore);
		Archive.Close();
		
		BasePath = TemporaryFolderToUnpacking + "\";
		FullPath = BasePath + FullPath + "\data.xml";
		
		DOMDocument = DOMDocument(FullPath);
		
		Extensions = GetExtesions(DOMDocument, BasePath);
		
		If Extensions.Count() > 0 Then
			
			ParametersStructure = New Structure("ArrayOfExtensions", Extensions);
			
			Try
				LoadExtensions(ParametersStructure, ResultStructure);
				ResultStructure.Done = True;
			Except
				ResultStructure.Done			= False;
				ResultStructure.ErrorMessage	= BriefErrorDescription(ErrorInfo());
			EndTry;
			
		EndIf;
		
	EndIf;
	
	Return ResultStructure;
	
EndFunction

Function GetExtesions(DOMDocument, ConfigurationPackagePath)
	
	Extesions = New Array();
	XPathResult = GetXPathResultByTagName(DOMDocument, "extension");
	
	DOMElement = XPathResult.IterateNext();
	While DOMElement <> Undefined Do
		
		ExtesionProperties = New Structure("Name, Data, Delete");
		
		PathToExtension = DOMElement.Attributes.GetNamedItem("path").NodeValue;
		FullPath = ConfigurationPackagePath + StrReplace(PathToExtension, "/", "\");
		
		ArrayOfString = StringFunctionsClientServer.SplitStringIntoSubstringsArray(PathToExtension, "/");
		ExtensionBinary = New BinaryData(FullPath);
		
		Action = DOMElement.Attributes.GetNamedItem("action").NodeValue;
		
		ExtesionProperties.Name = StrReplace(ArrayOfString[1], ".cfe", "");
		ExtesionProperties.Data = New ValueStorage(ExtensionBinary, New Deflation(9));
		ExtesionProperties.Delete = (Lower(Action) = "delete");
		
		Extesions.Add(ExtesionProperties);
		
		DOMElement = XPathResult.IterateNext();
	EndDo;
	
	Return Extesions;
	
EndFunction

Procedure LoadExtensions(ParametersStructure, ResultStructure)
	
	For Each ExternalExtension In ParametersStructure.ArrayOfExtensions Do
		
		Filter = New Structure("Name", ExternalExtension.Name);
		InternalExtensions = ConfigurationExtensions.Get(Filter);
		If InternalExtensions.Count() > 0 Then
			Extension = InternalExtensions[0];
		Else
			Extension = ConfigurationExtensions.Create();
		EndIf;
		
		Extension.SafeMode = False;
		Extension.UnsafeActionProtection = Common.ProtectionWithoutWarningsDetails();
		ExtensionData = ExternalExtension.Data.Get();
		Extension.Write(ExtensionData);
		
	EndDo;
	
EndProcedure

Procedure RunExtensionUpdateHandlers()
	
	Handlers = InfobaseUpdate.NewUpdateHandlerTable();
	
	For Each CommonModule In Metadata.CommonModules Do
		If StrFind(CommonModule.Name, "_InfobaseUpdate") Then
			Execute(CommonModule.Name + ".OnAddUpdateExtensionHandlers(Handlers)");
		EndIf;
	EndDo;
	
	CurrentVersion = Metadata.Version;
	For Each Handler In Handlers Do
		If CommonClientServer.CompareVersions(CurrentVersion, Handler.Version) = 0 Then
			Execute(Handler.Procedure + "()");
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

// Fill predefined data from the confugation package file.
//
// Parameters:
//	PathToDataFile - String - Path to data.xml at server.
//	BasePath       - String   - Path to default folder of data.xml.
//	UpdateConfiguration - Boolean - It shows what configuration was updated.
//	ExtensionsLoaded    - Boolean - It shows what extensions loaded.
//	Result - Structure  - Array of extension including in this structure.
//	CheckVersion        - Boolean - Check versions in configuration package file.
//
Procedure FillPredefinedData(PathToDataFile, BasePath = "", UpdateConfiguration, Result = Undefined, CheckVersion = True)
	
	DOMDocument = DOMDocument(PathToDataFile);
	
	If CheckVersion And Not VersionInConfigurationPackageIsCorrect(DOMDocument) Then
		Return;
	EndIf;
	
	CreatedElements = CreatedElements();
	
	LoadDataXML(DOMDocument, BasePath, UpdateConfiguration);
	
	If UpdateConfiguration Then
		XPathResult = GetXPathResultByTagName(DOMDocument, "item[@initial_filling=""False""]"); // select only items for update
	Else
		XPathResult = GetXPathResultByTagName(DOMDocument, "item"); // select all items
	EndIf;
	
	DOMElement = XPathResult.IterateNext();
	While DOMElement <> Undefined Do
		
		NodeName = DOMElement.Attributes.GetNamedItem("item_type").NodeValue;
		
		If NodeName = "catalog" Then
			LoadCatalogs(DOMElement, CreatedElements, Result);
		ElsIf NodeName = "constant" Then
			LoadConstants(DOMElement, CreatedElements);
		ElsIf NodeName = "data_processor" Then
			LoadDataProcessor(DOMElement, BasePath);
		ElsIf NodeName = "information_register" Then
			LoadInformationRegister(DOMElement, CreatedElements);
		ElsIf NodeName = "chart_of_accounts" Then
			LoadChartsOfAccounts(DOMElement, CreatedElements);
		ElsIf NodeName = "sl_data_xml" Then
			DOMElement = XPathResult.IterateNext();
			Continue; // this node was already loaded in
		ElsIf NodeName = "DefaultLanguage" Then
			LanguageIsChanged = False;
			SetDefaultLanguage(DOMElement, LanguageIsChanged);
			Result.Insert("LanguageIsChanged", LanguageIsChanged);
		Else
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'There is no event handler for the node ""%1""'; ru = 'Для узла ""%1"" не задан обработчик события';pl = 'Brak obsługi wydarzeń dla węzła ""%1""';es_ES = 'No hay un manipulador de eventos para el nodo ""%1""';es_CO = 'No hay un manipulador de eventos para el nodo ""%1""';tr = '""%1"" ünitesi için olay işleyicisi yoktur';it = 'Non c''è nessun gestore di eventi per il nodo ""%1""';de = 'Es gibt keinen Ereignis-Handler für den Knoten""%1""'", CommonClientServer.DefaultLanguageCode()),
				NodeName);
			WriteLogException(ErrorDescription);
		EndIf;
		
		DOMElement = XPathResult.IterateNext();
	EndDo;
	
EndProcedure

#Region LoadDataFromXML

Procedure LoadDataXML(DOMDocument, BasePath, UpdateConfiguration)
	
	If UpdateConfiguration Then
		XPathResult = GetXPathResultByTagName(DOMDocument, "item[@item_type=""sl_data_xml""][@initial_filling=""False""]"); // select only items for update
	Else
		XPathResult = GetXPathResultByTagName(DOMDocument, "item[@item_type=""sl_data_xml""]"); // select all items
	EndIf;
	
	DOMElement = XPathResult.IterateNext();
	While DOMElement <> Undefined Do
		DataPath = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
		LocalPath = BasePath + StrReplace(DataPath, "/", "\");
		
		FillBySLDataXML(LocalPath);
		DOMElement = XPathResult.IterateNext();
	EndDo;
	
EndProcedure

Procedure LoadConstants(DOMElement, CreatedElements)
	
	ConstantName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		ConstantManager = Constants[ConstantName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Can''t find constant ""%1"" in the configuration'; ru = 'В конфигурации отсутствует константа ""%1""';pl = 'Nie można znaleźć stałej ""%1"" w konfiguracji';es_ES = 'No se puede encontrar la constante ""%1"" en la configuración';es_CO = 'No se puede encontrar la constante ""%1"" en la configuración';tr = 'Yapılandırmada ""%1"" sabiti bulunamadı';it = 'Non riesci a trovare costante ""%1"" nella configurazione';de = 'Konstante ""%1"" in der Konfiguration nicht gefunden'", CommonClientServer.DefaultLanguageCode()),
			ConstantName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	CurrentConstantValue = ConstantManager.Get();
	ConstantValue = DOMElement.Attributes.GetNamedItem("value").NodeValue;
	
	NewValue = GetReferenceByValue(CurrentConstantValue, ConstantValue, CreatedElements);
	If NewValue = Undefined 
		And ConstantValue <> Undefined Then
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Can''t find value ""%1"" for constant ""%2"" in the configuration'; ru = 'Для константы ""%2"" отсутствует значение ""%1""';pl = 'Nie można znaleźć wartości ""%1"" dla stałej ""%2"" w konfiguracji';es_ES = 'No se puede encontrar el valor ""%1"" para la constante ""%2"" en la configuración';es_CO = 'No se puede encontrar el valor ""%1"" para la constante ""%2"" en la configuración';tr = 'Yapılandırmada ""%2"" sabiti için ""%1"" değeri bulunamadı';it = 'Non riesci a trovare il valore ""%1"" costante ""%2"" nella configurazione';de = 'Wert ""%1"" für Konstante ""%2"" in der Konfiguration nicht gefunden'", CommonClientServer.DefaultLanguageCode()),
			ConstantValue,
			ConstantName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndIf;
	
	Try
		ConstantManager.Set(NewValue);
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Can''t set value ""%1"" for constant ""%2""'; ru = 'Значение ""%1"" нельзя установить для константы ""%2""';pl = 'Nie można ustawić wartości ""%1"" dla stałej ""%2""';es_ES = 'No se puede establecer el valor ""%1"" para la constante ""%2""';es_CO = 'No se puede establecer el valor ""%1"" para la constante ""%2""';tr = '""%2"" sabiti için ""%1"" değeri ayarlanamaz';it = 'Non è possibile impostare il valore ""%1"" costante ""%2""';de = 'Wert ""%1"" für Konstante ""%2"" kann nicht eingestellt werden'", CommonClientServer.DefaultLanguageCode()),
			ConstantValue,
			ConstantName);
			
		WriteLogException(ErrorDescription);
	EndTry;
	
EndProcedure

Procedure LoadCatalogs(DOMElement, CreatedElements, Result)
	
	CatalogName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		CatalogManager = Catalogs[CatalogName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Can''t find catalog ""%1"" in the configuration'; ru = 'В конфигурации отсутствует справочник ""%1""';pl = 'Nie można znaleźć katalogu ""%1"" w konfiguracji';es_ES = 'No se puede encontrar el catálogo ""%1"" en la configuración';es_CO = 'No se puede encontrar el catálogo ""%1"" en la configuración';tr = 'Yapılandırmada ""%1"" kataloğu bulunamadı';it = 'Non è possibile trovare l''anagrafica ""%1"" nella configurazione';de = 'Verzeichnis ""%1"" kann nicht in der Konfiguration gefunden werden'", CommonClientServer.DefaultLanguageCode()),
			CatalogName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	ChildNodes = DomElement.ChildNodes;
	For Each Node In ChildNodes Do // elements in the catalog
	
		Attributes = New Structure();
		For Each Attribute In Node.ChildNodes Do // attribute of current element
			If ValueIsFilled(Attribute.LocalName) Then
				If Metadata.Catalogs[CatalogName].TabularSections.Find(Attribute.LocalName) <> Undefined Then
					Rows = New Array;
					For Each TS_Attribute In Attribute.ChildNodes Do
						TS_Attributes = New Structure();
						For Each Row In TS_Attribute.ChildNodes Do
							If ValueIsFilled(Row.LocalName) Then
								TS_Attributes.Insert(Row.LocalName, Row.TextContent);
							EndIf;
						EndDo;
						Rows.Add(TS_Attributes);
					EndDo;
					
					Attributes.Insert(Attribute.LocalName, Rows);
				Else
					Attributes.Insert(Attribute.LocalName, Attribute.TextContent);
				EndIf;
			EndIf;
		EndDo;
		
		Try
			
			ItemRef = Undefined;
			IsPredefinedElement = False;
			PredefinedKey = Undefined;
			
			Attributes.Property("Predefined", PredefinedKey);
			If ValueIsFilled(PredefinedKey) Then
				IsPredefinedElement = Boolean(PredefinedKey);
			EndIf;
			
			If IsPredefinedElement Then
				ItemRef = GetReferenceByValue(CatalogManager.EmptyRef(), Attributes["PredefinedDataName"], CreatedElements);
				PredefinedDataName = Attributes["PredefinedDataName"];
			Else
				ItemRef = GetReferenceByValue(CatalogManager.EmptyRef(), Attributes["Description"], CreatedElements);
			EndIf;
			
			If ItemRef = Undefined Then
				If Attributes.Property("Folder") = True Then
					Item = CatalogManager.CreateFolder();
				Else
					Item = CatalogManager.CreateItem();
				EndIf;
			Else
				Item = ItemRef.GetObject();
			EndIf;
			
			DeleteKeyInStructure(Attributes, "Predefined");
			DeleteKeyInStructure(Attributes, "PredefinedDataName");
			DeleteKeyInStructure(Attributes, "Folder");
			
			For Each Attribute In Attributes Do
				If Metadata.Catalogs[CatalogName].TabularSections.Find(Attribute.Key) <> Undefined Then
					For Each RowAttributes In Attribute.Value Do
						NewRow = Item[Attribute.Key].Add();
						For Each RowAttribute In RowAttributes Do
							NewRow[RowAttribute.Key] = GetReferenceByValue(NewRow[RowAttribute.Key], RowAttribute.Value, CreatedElements);
						EndDo;
					EndDo;
				Else
					Item[Attribute.Key] = GetReferenceByValue(Item[Attribute.Key], Attribute.Value, CreatedElements);
				EndIf;
			EndDo;
			
			If TypeOf(Item) = Type("CatalogObject.Calendars") Then
				Item.DataExchange.Load = True;
			EndIf;
			
			If TypeOf(Item) = Type("CatalogObject.Users") Then
				
				IBUserDetails = Users.NewIBUserDetails();
				IBUserDetails.Name = Item.Description;
				IBUserDetails.FullName = Item.Description;
				IBUserDetails.ShowInList = True;
				IBUserDetails.StandardAuthentication = True;
				IBUserDetails.Insert("Action", "Write");
				IBUserDetails.Insert("CanSignIn", True);
				
				If Item.Description = "Administrator" Then
					Item.AdditionalProperties.Insert("CreateAdministrator", "The first infobase user is granted administrator rights");
					Roles = New Array;
					Roles.Add("FullRights");
					Roles.Add("SystemAdministrator");
					IBUserDetails.Roles = Roles;
				EndIf;
				
				Item.AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
				Item.AdditionalProperties.Insert("CopyingValue", Catalogs.Users.EmptyRef());
				Item.AdditionalProperties.Insert("NewUserGroup", Catalogs.UserGroups.EmptyRef());
				
				Result.Insert("UserWasCreated", True);
				
			EndIf;
			
			Item.Write();
			
			AddCreatedElement(CreatedElements, Item);
			
		Except
			
			If IsPredefinedElement Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot save predefined item ""%1"" to catalog ""%2""'; ru = 'Не удается записать предопределенный элемент ""%1"" в справочник ""%2""';pl = 'Nie można zapisać predefiniowanego elementu ""%1"" do katalogu ""%2""';es_ES = 'Ha ocurrido un error al guardar el artículo predefinido ""%1"" en el catálogo ""%2""';es_CO = 'Ha ocurrido un error al guardar el artículo predefinido ""%1"" en el catálogo ""%2""';tr = '""%1"" öntanımlı öğesi ""%2"" kataloğuna kaydedilemiyor';it = 'Impossibile salvare l''elemento predefinito ""%1"" nel catalogo ""%2""';de = 'Fehler beim Speicher der vordefinierten Position ""%1"" im Katalog ""%2""'"),
					PredefinedDataName,
					CatalogName);
			Else
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot save item ""%1"" to catalog ""%2""'; ru = 'Не удается записать элемент ""%1"" в справочник ""%2""';pl = 'Nie można zapisać elementu ""%1"" do katalogu ""%2""';es_ES = 'Ha ocurrido un error al guardar el artículo ""%1"" en el catálogo ""%2""';es_CO = 'Ha ocurrido un error al guardar el artículo ""%1"" en el catálogo ""%2""';tr = '""%1"" öğesi ""%2"" kataloğuna kaydedilemiyor';it = 'Impossibile salvare l''elemento ""%1"" nel catalogo ""%2""';de = 'Fehler beim Speicher der Position ""%1"" im Katalog ""%2""'", CommonClientServer.DefaultLanguageCode()),
					Attributes["Description"],
					CatalogName);
			EndIf;
			
			WriteLogException(ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure LoadDataProcessor(DOMElement, BasePath)
	
	DataProcessorPath = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	LocalPath = BasePath + StrReplace(DataProcessorPath, "/", "\");
	BinaryData = New BinaryData(LocalPath);
	
	SubstringArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(DataProcessorPath, "\");
	
	DataProcessorFileName = SubstringArray.Get(SubstringArray.UBound());
	FileExtension = Upper(Right(DataProcessorFileName, 3));
	
	If FileExtension <> "ERF"
		And FileExtension <> "EPF" Then
		
		ErrorDescription = NStr("en = 'File extension ""%1"" does not match those of the external report (ERF) or data processor (EPF).'; ru = 'Файл ""%1"" имеет расширение, не соответствующее расширению внешнего отчета (ERF) или обработки (EPF).';pl = 'Rozszerzenie pliku ""%1"" nie jest zgodne ze sprawozdaniem zewnętrznym (ERF) lub procesorem danych (EPF).';es_ES = 'Extensión del archivo ""%1"" no coincide con aquellas del informe externo (ERF) o del procesador de datos (EPF).';es_CO = 'Extensión del archivo ""%1"" no coincide con aquellas del informe externo (ERF) o del procesador de datos (EPF).';tr = 'Dosya uzantısı ""%1"" harici rapor (ERF) veya veri işlemcisi (EPF) ile uyuşmuyor.';it = 'L''estensione del file ""%1"" non corrisponde a quelle del report esterno (ERF) o al processore di dati (EPF).';de = 'Die Dateierweiterung ""%1"" stimmt nicht mit der des externen Berichts (ERF) oder des Datenverarbeiters (EPF) überein.'",
			CommonClientServer.DefaultLanguageCode());
			
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, FileExtension);
			
		WriteLogException(ErrorDescription);
		Return;
	EndIf;
	
	RegistrationParameters = New Structure();
	RegistrationParameters.Insert("DataProcessorDataAddress", PutToTempStorage(BinaryData));
	RegistrationParameters.Insert("DisableConflicts", False);
	RegistrationParameters.Insert("Success", False);
	RegistrationParameters.Insert("FileName", DataProcessorFileName);
	RegistrationParameters.Insert("IsReport", FileExtension = "ERF");
	RegistrationParameters.Insert("DisablePublication", False);
	RegistrationParameters.Insert("UnsafeOperation", False);
	
	DataProcessor = Catalogs.AdditionalReportsAndDataProcessors.CreateItem();
	DataProcessor.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
	
	Result = AdditionalReportsAndDataProcessors.RegisterDataProcessor(DataProcessor, RegistrationParameters);
	
	If Not Result.Success Then
		If Result.Property("Conflicting")
			And ValueIsFilled(Result.Conflicting) Then
			
			RegistrationParameters.Insert("Conflicting", Result.Conflicting);
			RegistrationParameters.DisableConflicts = True;
			Result = AdditionalReportsAndDataProcessors.RegisterDataProcessor(DataProcessor, RegistrationParameters);
		EndIf;
	EndIf;
	
	If Not Result.Success Then
		WriteLogException(Result.ErrorText);
		Return;
	EndIf;
	
	BinaryData = GetFromTempStorage(RegistrationParameters.DataProcessorDataAddress);
	DataProcessor.DataProcessorStorage = New ValueStorage(BinaryData, New Deflation(9));
	
	Try
		DataProcessor.Write();
	Except
		WriteLogException();
	EndTry;
	
EndProcedure

Procedure LoadInformationRegister(DOMElement, CreatedElements)
	
	RegisterName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		RegisterManager = InformationRegisters[RegisterName];
	Except
		ErrorDescription = NStr("en = 'Can''t find information register  ""%1"" in the configuration'; ru = 'В конфигурации отсутствует регистр сведений ""%1""';pl = 'Nie można znaleźć rejestru informacji ""%1"" w konfiguracji';es_ES = 'No se puede encontrar el registro de información ""%1"" en la configuración';es_CO = 'No se puede encontrar el registro de información ""%1"" en la configuración';tr = 'Yapılandırmada bilgi kaydı ""%1"" bulunamadı';it = 'Non è possibile trovare il registro informazioni ""%1"" nella configurazione';de = 'Informationsregister ""%1"" kann nicht gefunden werden in der Konfiguration'",
			CommonClientServer.DefaultLanguageCode());
			
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, RegisterName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	RecorsNodes = DomElement.ChildNodes;
	For Each RecordNode In RecorsNodes Do // records of the information register
		
		NewRecord = RegisterManager.CreateRecordManager();
		For Each Attribute In RecordNode.ChildNodes Do // attrubute of current record
			
			AttributeName = Attribute.TagName;
			
			Try
				RecordAttribute = NewRecord[Attribute.TagName];
			Except
				ErrorDescription = NStr("en = 'There is no attribute ""%1"" in information register ""%2""'; ru = 'В регистре сведений ""%2"" нет реквизита ""%1""';pl = 'Brak atrybutu ""%1"" w rejestrze informacji ""%2""';es_ES = 'No hay el atributo ""%1"" en el registro de información ""%2""';es_CO = 'No hay el atributo ""%1"" en el registro de información ""%2""';tr = '""%2"" bilgi kaydında ""%1"" özniteliği yok';it = 'Non vi è alcun attributo ""%1"" nel registro informazioni ""%2""';de = 'Es gibt kein Attribut ""%1"" im Informationsregister ""%2""'",
					CommonClientServer.DefaultLanguageCode());
					
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					ErrorDescription,
					AttributeName,
					RegisterName);
					
				WriteLogException(ErrorDescription);
				Return;
			EndTry;
			
			AttributeValue = Attribute.TextContent;
			
			InfobaseObject = GetReferenceByValue(RecordAttribute, AttributeValue, CreatedElements);
			If InfobaseObject = Undefined 
				And AttributeValue <> Undefined Then
				
				ErrorDescription =  NStr("en = 'Can''t find value ""%1"" for information register ""%2"" in the configuration'; ru = 'В регистре сведений ""%2"" отсутствует значение ""%1""';pl = 'Nie można znaleźć wartości ""%1"" dla rejestru informacji ""%2"" w konfiguracji';es_ES = 'No se puede encontrar el valor ""%1"" para el registro de información ""%2"" en la configuración';es_CO = 'No se puede encontrar el valor ""%1"" para el registro de información ""%2"" en la configuración';tr = 'Yapılandırmada bilgi kaydı %1 için ""%2"" değerini bulunamadı';it = 'Non riesci a trovare il valore ""%1"" per il registro informazioni ""%2"" nella configurazione';de = 'Der Wert ""%1"" für das Informationsregister ""%2"" in der Konfiguration kann nicht gefunden werden'",
					CommonClientServer.DefaultLanguageCode());
					
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					ErrorDescription,
					AttributeValue,
					RegisterName);
					
				WriteLogException(ErrorDescription);
				Return;
			EndIf;
			
			NewRecord[Attribute.TagName] = InfobaseObject;
			
		EndDo;
		
		Try
			NewRecord.Write();
		Except
			WriteLogException();
			Return;
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure LoadChartsOfAccounts(DOMElement, CreatedElements)
	
	ChartOfAccountsName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		ChartOfAccountsManager = ChartsOfAccounts[ChartOfAccountsName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Can''t find chart of accounts ""%1"" in the configuration'; ru = 'В конфигурации отсутствует план счетов ""%1""';pl = 'Nie można znaleźć planu kont ""%1"" w konfiguracji';es_ES = 'No se puede encontrar el diagrama de cuentas ""%1"" en la configuración';es_CO = 'No se puede encontrar el diagrama de cuentas ""%1"" en la configuración';tr = 'Yapılandırmada ""%1"" hesap planı bulunamadı';it = 'Non è possibile trovare il piano dei conti ""%1"" nella configurazione';de = 'Kann Kontenplan ""%1"" in der Konfiguration nicht finden'", CommonClientServer.DefaultLanguageCode()),
			ChartOfAccountsName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	Accounts = DomElement.ChildNodes;
	For Each Account In Accounts Do
		
		AttributesValue = New Structure();
		For Each Attribute In Account.ChildNodes Do // attribute of current account
			AttributesValue.Insert(Attribute.LocalName, Attribute.TextContent);
		EndDo;
		
		AccountDescription = AttributesValue["Description"];
		
		AccountRef = ChartOfAccountsManager.FindByDescription(AccountDescription);
		If ValueIsFilled(AccountRef) Then
			AccountObject = AccountRef.GetObject();
		Else
			AccountObject = ChartOfAccountsManager.CreateAccount();
		EndIf;
		
		For Each Attribute In AttributesValue Do
			
			If Common.IsReference(TypeOf(AccountObject[Attribute.Key])) Then
				
				ObjectManager = Common.ObjectManagerByRef(AccountObject[Attribute.Key]);
				AccountObject[Attribute.Key] = GetReferenceByValue(ObjectManager.EmptyRef(),
					Attribute.Value,
					CreatedElements,
					False);

			ElsIf TypeOf(AccountObject[Attribute.Key]) = Type("AccountType") Then
				AccountObject[Attribute.Key] = AccountType[Attribute.Value];
			Else
				AccountObject[Attribute.Key] = Attribute.Value;
			Endif 
			
		EndDo;
		
		Try
			AccountObject.Write();
		Except
			
			ErrorDescription = NStr("en = 'Cannot create account ""%1"" in charts of accounts ""%2""'; ru = 'Не удается создать счет ""%1"" в плане счетов ""%2""';pl = 'Nie można utworzyć konta ""%1"" w planie kont ""%2""';es_ES = 'Ha ocurrido un error al crear la cuenta ""%1"" en los diagramas de cuentas ""%2""';es_CO = 'Ha ocurrido un error al crear la cuenta ""%1"" en los diagramas de cuentas ""%2""';tr = '""%2"" hesap planında ""%1"" hesabı oluşturulamadı';it = 'Impossibile creare conto ""%1"" nel piano dei conti ""%2""';de = 'Konto ""%1"" kann nicht in den Kontenplänen ""%2"" erstellt werden'",
				CommonClientServer.DefaultLanguageCode());
				
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				ErrorDescription,
				AccountDescription,
				ChartOfAccountsName);
			
			WriteLogException(ErrorDescription);
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure SetDefaultLanguage(DOMElement, LanguageIsChanged)
	
	LanguageName = DOMElement.Attributes.GetNamedItem("item_name").NodeValue;
	
	Try
		Langugage = Metadata.Languages[LanguageName];
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Can''t find language ""%1"" in the configuration'; ru = 'В конфигурации не найден язык ""%1""';pl = 'Nie można znaleźć języka ""%1"" w konfiguracji';es_ES = 'No se puede encontrar el idioma ""%1"" en la configuración';es_CO = 'No se puede encontrar el idioma ""%1"" en la configuración';tr = 'Yapılandırmada ""%1"" dili bulunamadı';it = 'Non è possibile trovare la lingua ""%1"" nella configurazione';de = 'Sprache ""%1"" in der Konfiguration nicht gefunden'", CommonClientServer.DefaultLanguageCode()),
			LanguageName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
	UserName = "Administrator";
	DefaultUser = InfoBaseUsers.FindByName(UserName);
	If DefaultUser = Undefined Then
		ListOfUsers = InfoBaseUsers.GetUsers();
		If ListOfUsers.Count() = 0 Then 
			Return;
		EndIf;
		DefaultUser = ListOfUsers[0];
	EndIf;
	
	If DefaultUser.Language <> Langugage
		And Metadata.DefaultLanguage <> Langugage Then
		DefaultUser.Language = Langugage;
		LanguageIsChanged = True;
	Else
		LanguageIsChanged = False;
		Return;
	EndIf;
	
	Try
		DefaultUser.Write();
	Except
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Can''t set language on user ""%1""'; ru = 'Невозможно установить язык для пользователя ""%1""';pl = 'Nie można ustawić języka dla użytkownika ""%1""';es_ES = 'No se puede establecer el idioma para el usuario ""%1""';es_CO = 'No se puede establecer el idioma para el usuario ""%1""';tr = '""%1"" kullanıcısında dil ayarlanamadı';it = 'Non è possibile impostare la lingua sull''utente ""%1""';de = 'Sprache für Benutzer ""%1"" kann nicht eingestellt werden'", CommonClientServer.DefaultLanguageCode()),
			UserName);
			
		WriteLogException(ErrorDescription);
		Return;
	EndTry;
	
EndProcedure

#EndRegion

#Region DOMDocument

Function DOMDocument(Path)
	
	XMLReader = New XMLReader;
	DOMBuilder = New DOMBuilder;
	XMLReader.OpenFile(Path);
	DOMDocument = DOMBuilder.Read(XMLReader);
	XMLReader.Close();
	
	Return DOMDocument;
	
EndFunction

Function GetXPathResultByTagName(DOMDocument, TagName)
	
	Resolver = DOMDocument.CreateNSResolver();
	XPathResult = DOMDocument.EvaluateXPathExpression("//xmlns:" + TagName, DOMDocument, Resolver);
	
	Return XPathResult;
EndFunction

#EndRegion

#Region Other

Function GetReferenceByValue(EmptyValue, NewValue, CreatedElements, FillingCheck = True)
	
	InfobaseObject = Undefined;
	
	TypeOfEmptyValue = TypeOf(EmptyValue);
	If TypeOfEmptyValue = Type("Number")
		Or TypeOfEmptyValue = Type("String")
		Or TypeOfEmptyValue = Type("Date")
		Or TypeOfEmptyValue = Type("Boolean")
		Or TypeOfEmptyValue = Type("UUID") Then
		
		InfobaseObject = NewValue;
	ElsIf Enums.AllRefsType().ContainsType(TypeOfEmptyValue) Then
		
		ValueType = EmptyValue.Metadata();
		InfobaseObject = Enums[ValueType.Name][NewValue];
		
	Else
		Filter = New Structure("Type, Description", TypeOfEmptyValue, NewValue);
		FoundedElements = CreatedElements.FindRows(Filter);
		If FoundedElements.Count() > 0 Then
			InfobaseObject = FoundedElements[0].Ref;
		Else
			If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOfEmptyValue)
				Or ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOfEmptyValue)
				Or ChartsOfAccounts.AllRefsType().ContainsType(TypeOfEmptyValue)
				Or Catalogs.AllRefsType().ContainsType(TypeOfEmptyValue) Then
				
				MetadataObject = EmptyValue.Metadata();
				PredefinedElements = MetadataObject.GetPredefinedNames();
				
				Index = PredefinedElements.Find(NewValue);
				If Index <> Undefined Then
					
					ValueType = EmptyValue.Metadata();
					TypeManager = Common.ObjectManagerByFullName(ValueType.FullName());
					
					InfobaseObject = TypeManager[NewValue];
				EndIf;
			EndIf;
				
			If InfobaseObject = Undefined Then
				If Catalogs.AllRefsType().ContainsType(TypeOfEmptyValue)
					Or ChartsOfAccounts.AllRefsType().ContainsType(TypeOfEmptyValue) Then
					
					ValueType = EmptyValue.Metadata();
					TypeManager = Common.ObjectManagerByFullName(ValueType.FullName());
					
					FoundedObject = TypeManager.FindByDescription(NewValue, True);
					If NOT ValueIsFilled(FoundedObject) Then
						FoundedObject = TypeManager.FindByCode(NewValue);
					EndIf;
					If ValueIsFilled(FoundedObject) Then
						InfobaseObject = FoundedObject;
					EndIf;
				ElsIf FillingCheck Then
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Can''t find metadata ""%1"" for type ""%2""'; ru = 'Для типа ""%2"" не найдены метаданные ""%1""';pl = 'Nie można znaleźć metadanych ""%1"" dla typu ""%2""';es_ES = 'No se puede encontrar los metadatos ""%1"" para el tipo ""%2""';es_CO = 'No se puede encontrar los metadatos ""%1"" para el tipo ""%2""';tr = '""%2"" türü için ""%1"" meta verisi bulunamadı';it = 'Impossibile trovare i metadati ""%1"" per il tipo ""%2""';de = 'Metadaten ""%1"" für Typ ""%2"" nicht gefunden'", CommonClientServer.DefaultLanguageCode()),
						NewValue,
						TypeOfEmptyValue);
					WriteLogException(ErrorDescription)
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Return InfobaseObject;
EndFunction

Procedure WriteLogException(ErrorDescription = Undefined)
	
	If Not ValueIsFilled(ErrorDescription) Then
		ErrorDescription = BriefErrorDescription(ErrorInfo());
	EndIf;
	
	WriteLogEvent(
		NStr("en = 'UpdateResults.LoadPredefinedData'; ru = 'UpdateResults.LoadPredefinedData';pl = 'UpdateResults.LoadPredefinedData';es_ES = 'ActualizarResultados.CargarDatosPredefinidos';es_CO = 'ActualizarResultados.CargarDatosPredefinidos';tr = 'UpdateResults.LoadPredefinedData';it = 'UpdateResults.LoadPredefinedData';de = 'UpdateResults.LoadPredefinedData'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Error,
		Metadata.CommonModules.InfobaseUpdateDrive,
		,
		ErrorDescription);
		
	Raise ErrorDescription;
	
EndProcedure

Function JobResult()
	
	Result  = New Structure;
	Result.Insert("Done",				True);
	Result.Insert("ErrorMessage",		"");
	Result.Insert("LanguageIsChanged",	False);
	Result.Insert("UserWasCreated",		False);
	
	Return Result;

EndFunction

Function FileExist(PathToFile)
	TempFile = New File(PathToFile);
	Return TempFile.Exist()
EndFunction

Procedure DeleteKeyInStructure(Structure, KeyName)
	
	If Structure.Property(KeyName) Then
		Structure.Delete(KeyName);
	EndIf;
	
EndProcedure

Function VersionInConfigurationPackageIsCorrect(DOMDocument)
	
	XPathResult = GetXPathResultByTagName(DOMDocument, "items[@version]");
	
	DOMElement = XPathResult.IterateNext();
	If DOMElement <> Undefined Then
		
		ConfigurationPackageVersion = DOMElement.Attributes.GetNamedItem("version").NodeValue;
		CurrentConfigurationVersion = Metadata.Version;
		
		If CommonClientServer.CompareVersions(ConfigurationPackageVersion, CurrentConfigurationVersion) = 0 Then
			VersionIsCorrect = True;
		Else
			VersionIsCorrect = False;
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'There is incorrect version in configuration package file.
				     |Configuration version is ""%1"".
				     |Configuration package file version is ""%2""'; 
				     |ru = 'В файле поставки конфигурации указана неправильная версия.
				     |Версия конфигурации – ""%1"".
				     | Версия конфигурации файла поставки – ""%2"".';
				     |pl = 'W pliku pakietu konfiguracyjnego znajduje się niepoprawna wersja.
				     | Wersja konfiguracji to ""%1"".
				     | Wersja pliku pakietu konfiguracyjnego to ""%2""';
				     |es_ES = 'Hay una versión incorrecta en el archivo del paquete de configuración.
				     |Versión de la configuración es ""%1"".
				     |Versión del archivo del paquete de configuración es ""%2""';
				     |es_CO = 'Hay una versión incorrecta en el archivo del paquete de configuración.
				     |Versión de la configuración es ""%1"".
				     |Versión del archivo del paquete de configuración es ""%2""';
				     |tr = 'Yapılandırma paketi dosyasında yanlış sürüm. 
				     |Yapılandırma sürümü ""%1"" dir. 
				     |Yapılandırma paketi dosya sürümü ""%2"" dir';
				     |it = 'C''è un versione non corretta nel file del pacchetto di configurazione.
				     |La versione di configurazione è ""%1"".
				     |La versione del file del pacchetto di configurazione è ""%2""';
				     |de = 'Die Konfigurationspaketdatei enthält eine falsche Version.
				     |Konfigurationsversion ist ""%1"".
				     |Version der Konfigurationspaketdatei ist ""%2""'"),
				CurrentConfigurationVersion,
				ConfigurationPackageVersion);
			WriteLogException(ErrorDescription);
		EndIf;
	Else
		ErrorDescription = NStr("en = 'There is no version number in the configuration package file'; ru = 'В файле поставки конфигурации не указана версия.';pl = 'W pliku konfiguracyjnym nie ma numeru wersji';es_ES = 'No hay un número de versión en el archivo del paquete de configuración';es_CO = 'No hay un número de versión en el archivo del paquete de configuración';tr = 'Yapılandırma paketi dosyasında sürüm numarası yok';it = 'Non c''è il numero di versione nel file di pacchetto di configurazione';de = 'Die Konfigurationspaketdatei enthält keine Versionsnummer'",
			CommonClientServer.DefaultLanguageCode());
		WriteLogException(ErrorDescription);
		VersionIsCorrect = False;
	EndIf;
	
	Return VersionIsCorrect;
EndFunction

Procedure SetUpdateConfigurationPackage()
	
	If Constants.FirstLaunchPassed.Get() Then
		
		LaunchParameter = SessionParameters.ClientParametersAtServer.Get("LaunchParameter");
		If Not ValueIsFilled(LaunchParameter)
			Or StrFind(LaunchParameter, "DisableUpdateConfigurationPackage") = 0 Then
			Constants.UpdateConfigurationPackage.Set(True);
		Else
			Constants.UpdateConfigurationPackage.Set(False);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CreatedElements

Function CreatedElements()
	
	CreatedElements = New ValueTable;
	CreatedElements.Columns.Add("Type");
	CreatedElements.Columns.Add("Description");
	CreatedElements.Columns.Add("Ref");
	
	Return CreatedElements;
	
EndFunction

Procedure AddCreatedElement(CreatedElements, NewObject)
	
	NewElement = CreatedElements.Add();
	NewElement.Type 		= TypeOf(NewObject.Ref);
	NewElement.Description	= NewObject.Description;
	NewElement.Ref			= NewObject.Ref;
	
EndProcedure

#EndRegion

#Region SLDataXMLLoad

// Function start filling data for choisen country
// 
// Parameters:
//    FileName - string - 
//
Function FillBySLDataXML(Val FileName)
	
	File = New File(FileName);
	
	If File.Extension = ".fi" 
		Or File.Extension = ".finf" Then
		
		XMLReader = New FastInfosetReader;
		XMLReader.Read();
		XMLReader.OpenFile(FileName);
		
		XMLWriter = New XMLWriter;
		TempFileName = GetTempFileName("xml");
		XMLWriter.OpenFile(TempFileName, "UTF-8");
		
		While XMLReader.Read() Do
			XMLWriter.WriteCurrent(XMLReader);
		EndDo;
		
		XMLWriter.Close();
		
		FileName = TempFileName;
		
	EndIf;
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(FileName);
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.StartElement
		OR XMLReader.LocalName <> "_1CV8DtUD"
		OR XMLReader.NamespaceURI <> "http://www.1c.ru/V8/1CV8DtUD/" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	ElsIf Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.StartElement
		OR XMLReader.LocalName <> "Data" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	MapReplaceOfRef = New Map;
	
	LoadTableOfPredifined(XMLReader, MapReplaceOfRef);
	ReplaceRefToPredefined(FileName, MapReplaceOfRef);
	
	XMLReader.OpenFile(FileName);
	XMLReader.Read();
	XMLReader.Read();
	
	If Not XMLReader.Read() Then 
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	Serializer = InitializateSerializatorXDTOWithAnnotationTypes();
	
	While Serializer.CanReadXML(XMLReader) Do
		
		Try
			WriteValue = Serializer.ReadXML(XMLReader);
		Except
			Raise;
		EndTry;
		
		Try
			WriteValue.DataExchange.Load = True;
		Except
		EndTry;
		
		Try
			WriteValue.Write();
		Except
			
			ErrorText = ErrorDescription();
			
			Try
				TextForMessage = NStr("en = 'In loading process for Object %1(%2) raised error: %3'; ru = 'При загрузке объекта %1(%2) возникла ошибка: %3';pl = 'W procesie przesyłania obiektu %1(%2) wystąpił błąd: %3';es_ES = 'Cargando ha surgido el error surgido del Objeto %1(%2): %3';es_CO = 'Cargando ha surgido el error surgido del Objeto %1(%2): %3';tr = 'Nesne %1(%2) için yükleme işleminde hata oluştu:%3';it = 'Durante il processo di caricamento per l''Oggetto %1(%2) si è verificato un errore: %3';de = 'Im Ladeprozess für Objekt %1(%2) ist ein Fehler aufgetreten: %3'");
				TextForMessage = StringFunctionsClientServer.SubstituteParametersToString(TextForMessage, WriteValue, TypeOf(WriteValue), ErrorText);
			Except
				TextForMessage = NStr("en = 'In loading data process raised error: %1'; ru = 'При загрузке данных возникла ошибка: %1';pl = 'Podczas ładowania danych wystąpił błąd: %1';es_ES = 'Cargando los datos ha surgido el error: %1';es_CO = 'Cargando los datos ha surgido el error: %1';tr = 'Veri yükleme aşamasında hata oluştu:%1';it = 'Nel processo di caricamento dei dati si è verificato un errore: %1';de = 'Beim Laden der Daten ist ein Fehler aufgetreten: %1'");
				TextForMessage = StringFunctionsClientServer.SubstituteParametersToString(TextForMessage, ErrorText);
			EndTry;
			
			CommonClientServer.MessageToUser(TextForMessage);
			
		EndTry;
		
	EndDo;
	
	If XMLReader.NodeType <> XMLNodeType.EndElement
		OR XMLReader.LocalName <> "Data" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.StartElement
		OR XMLReader.LocalName <> "PredefinedData" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	XMLReader.Skip();
	
	If Not XMLReader.Read()
		OR XMLReader.NodeType <> XMLNodeType.EndElement
		OR XMLReader.LocalName <> "_1CV8DtUD"
		OR XMLReader.NamespaceURI <> "http://www.1c.ru/V8/1CV8DtUD/" Then
		
		RaiseExceptionBadFormat();
		Return False;
		
	EndIf;
	
	XMLReader.Close();
	
	Return True;
	
EndFunction

Procedure RaiseExceptionBadFormat()

	Raise NStr("en = 'File format is wrong.'; ru = 'Неверный формат файла выгрузки.';pl = 'Błędny format pliku.';es_ES = 'Formato del archivo es erróneo.';es_CO = 'Formato del archivo es erróneo.';tr = 'Dosya formatı yanlış.';it = 'Il formato File è sbagliato.';de = 'Das Dateiformat ist falsch.'");
	
EndProcedure

Function InitializateTableOfPredifined()
	
	TableOfPredifined = New ValueTable;
	TableOfPredifined.Columns.Add("TableName");
	TableOfPredifined.Columns.Add("Ref");
	TableOfPredifined.Columns.Add("PredefinedDataName");
	
	Return TableOfPredifined;
	
EndFunction

Procedure LoadTableOfPredifined(XMLReader, MapReplaceOfRef)
	
	XMLReader.Skip();
	XMLReader.Read();
	
	TableOfPredifined = InitializateTableOfPredifined();
	TempRow = TableOfPredifined.Add();
	
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			If XMLReader.LocalName <> "item" Then
				
				TempRow.TableName = XMLReader.LocalName;
				
				TextQuery = 
				"Select
				|	Table.Ref AS Ref
				|From
				|	" + TempRow.TableName + " AS Table
				|Where
				|	Table.PredefinedDataName = &PredefinedDataName";
				Query = New Query(TextQuery);
				
			Else
				While XMLReader.ReadAttribute() Do
					TempRow[XMLReader.LocalName] = XMLReader.Value;
				EndDo;
				
				CheckPredefinedValue(TempRow.TableName, TempRow.PredefinedDataName);
				
				Query.SetParameter("PredefinedDataName", TempRow.PredefinedDataName);
				
				QueryResult = Query.Execute();
				If Not QueryResult.IsEmpty() Then
					
					Selecter = QueryResult.Select();
					
					If Selecter.Count() = 1 Then
						
						Selecter.Next();
						
						RefInIB = XMLString(Selecter.Ref);
						RefInFile = TempRow.Ref;
						
						If RefInIB <> RefInFile Then
							
							XMLType = XMLTypeOfRef(Selecter.Ref);
							
							MapType = MapReplaceOfRef.Get(XMLType);
							
							If MapType = Undefined Then
								
								MapType = New Map;
								MapType.Insert(RefInFile, RefInIB);
								MapReplaceOfRef.Insert(XMLType, MapType);
								
							Else
								MapType.Insert(RefInFile, RefInIB);
							EndIf;
						EndIf;
					Else
						
						Raise StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'Predefined elements %1 are duplicated in table %2.'; ru = 'Обнаружено дублирование предопределенных элементов %1 в таблице %2.';pl = 'W tabeli %2 znajdują się zduplikowane predefiniowane elementy %1';es_ES = 'Elementos predefinidos %1 están duplicados en la tabla %2.';es_CO = 'Elementos predefinidos %1 están duplicados en la tabla %2.';tr = 'Ön tanımlı %1öğeler tabloda çoğaltıldı%2.';it = 'Elementi predefiniti %1 sono duplicati nella tabella ""%2"".';de = 'Vordefinierte Elemente %1 werden in der Tabelle dupliziert %2.'"),
								TempRow.PredefinedDataName, 
								TempRow.TableName);
						
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	XMLReader.Close();
	
EndProcedure

Procedure CheckPredefinedValue(TableName, PredefinedDataName)
	
	StringPredefinedItem = TableName + "." + PredefinedDataName;
	
	Try
		PredefinedItem = PredefinedValue(StringPredefinedItem);
	Except
		TextRaise = NStr("en = 'Predefined object ""%1"" does not exist'; ru = 'Предопределенный объект ""%1"" не существует';pl = 'Przedefiniowany obiekt ""%1"" nie istnieje';es_ES = 'El objeto predefinido ""%1"" no existe';es_CO = 'El objeto predefinido ""%1"" no existe';tr = '""%1"" öntanımlı nesnesi mevcut değil';it = 'L''oggetto predefinito ""%1"" non esiste';de = 'Vordefiniertes Objekt ""%1"" existiert nicht'");
		TextRaise = StringFunctionsClientServer.SubstituteParametersToString(
			TextRaise,
			StringPredefinedItem);
			
		Raise TextRaise;
	EndTry;
	
EndProcedure

// Return XDTOSerializer with annotation type.
//
// Return value:
//	XDTOSerializer - Serializer.
//
Function InitializateSerializatorXDTOWithAnnotationTypes()
	
	TypeWithAnotationsRef = PredifinedTypeForUnload();
	
	If TypeWithAnotationsRef.Count() > 0 Then
		Factory = FactoryWithTypes(TypeWithAnotationsRef);
		Serializer = New XDTOSerializer(Factory);
	Else
		Serializer = XDTOSerializer;
	EndIf;
	
	Return Serializer;
	
EndFunction

Function PredifinedTypeForUnload()
	
	Types = New Array;
	
	For Each MetadataObject In Metadata.Catalogs Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfAccounts Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfCharacteristicTypes Do
		Types.Add(MetadataObject);
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfCalculationTypes Do
		Types.Add(MetadataObject);
	EndDo;
	
	Return Types;
	
EndFunction

Function FactoryWithTypes(Val Types)
	
	SchemaSet = XDTOFactory.ExportXMLSchema("http://v8.1c.ru/8.1/data/enterprise/current-config");
	Schema = SchemaSet[0];
	Schema.UpdateDOMElement();
	
	SpecifiedTypes = New Map;
	For Each Type In Types Do
		SpecifiedTypes.Insert(XMLTypeOfRef(Type), True);
	EndDo;
	
	NameSpace = New Map;
	NameSpace.Insert("xs", "http://www.w3.org/2001/XMLSchema");
	DOMNamespaceResolver = New DOMNamespaceResolver(NameSpace);
	TextXPath = "/xs:schema/xs:complexType/xs:sequence/xs:element[starts-with(@type,'tns:')]";
	
	Query = Schema.DOMDocument.CreateXPathExpression(TextXPath, DOMNamespaceResolver);
	Result = Query.Evaluate(Schema.DOMDocument);

	While True Do
		
		Node = Result.IterateNext();
		If Node = Undefined Then
			Break;
		EndIf;
		TypeAttribute = Node.Attributes.GetNamedItem("type");
		TypeWithoutNSPrefix = Mid(TypeAttribute.TextContent, StrLen("tns:") + 1);
		
		If SpecifiedTypes.Get(TypeWithoutNSPrefix) = Undefined Then
			Continue;
		EndIf;
		
		Node.SetAttribute("nillable", "true");
		Node.RemoveAttribute("type");
	EndDo;
	
	XMLWriter = New XMLWriter;
	SchemeFileName = GetTempFileName("xsd");
	XMLWriter.OpenFile(SchemeFileName);
	DOMWriter = New DOMWriter;
	DOMWriter.Write(Schema.DOMDocument, XMLWriter);
	XMLWriter.Close();
	
	Factory = CreateXDTOFactory(SchemeFileName);
	
	Try
		DeleteFiles(SchemeFileName);
	Except
	EndTry;
	
	Return Factory;
	
EndFunction

Function XMLTypeOfRef(Val Value)
	
	If TypeOf(Value) = Type("MetadataObject") Then
		MetadataObject = Value;
		ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		Ref = ObjectManager.GetRef();
	Else
		MetadataObject = Value.Metadata();
		Ref = Value;
	EndIf;
	
	If ObjectFormsReferenceType(MetadataObject) Then
		
		Return XDTOSerializer.XMLTypeOf(Ref).TypeName;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Error in definition XMLType reference for object %1: object is not reference.'; ru = 'Ошибка при определении XML типа ссылки для объекта %1: объект не является ссылочным.';pl = 'Błąd w definicji XMLType Typ odsyłacza dla obiektu %1: nie jest odsyłaczem.';es_ES = 'Error en la referencia XMLTipo de definición para el objeto %1: objeto no es una referencia.';es_CO = 'Error en la referencia XMLTipo de definición para el objeto %1: objeto no es una referencia.';tr = '%1Nesne için XMLType referans tanımı hatası: nesne referans nesnesi değil.';it = 'Errore nella definizione del riferimento tipo XMLT per l''oggetto %1: l''oggetto non è riferimento.';de = 'Fehler in der Definition XML-Typ-Referenz für Objekt %1: Objekt ist keine Referenz.'"),
					MetadataObject.FullName()
				);
		
	EndIf;
	
EndFunction

Function ObjectFormsReferenceType(ObjectMD)
	
	If ObjectMD = Undefined Then
		Return False;
	EndIf;
	
	If Metadata.Catalogs.Contains(ObjectMD)
		OR Metadata.Documents.Contains(ObjectMD)
		OR Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMD)
		OR Metadata.ChartsOfAccounts.Contains(ObjectMD)
		OR Metadata.ChartsOfCalculationTypes.Contains(ObjectMD)
		OR Metadata.ExchangePlans.Contains(ObjectMD)
		OR Metadata.BusinessProcesses.Contains(ObjectMD)
		OR Metadata.Tasks.Contains(ObjectMD) Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

Procedure ReplaceRefToPredefined(FileName, MapReplaceOfRef)
	
	ReadFlow = New TextReader(FileName);
	
	TempFile = GetTempFileName("xml");
	
	WriteFlow = New TextWriter(TempFile);
	
	// Constans for parse text
	StartOfType = "xsi:type=""v8:";
	LengthStartOfType = StrLen(StartOfType);
	EndOfType = """>";
	LengthEndOfType = StrLen(EndOfType);
	
	SourceRow = ReadFlow.ReadLine();
	While SourceRow <> Undefined Do
		
		RemainsOfRow = Undefined;
		
		CurrentPosition = 1;
		TypePosition = Find(SourceRow, StartOfType);
		While TypePosition > 0 Do
			
			WriteFlow.Write(Mid(SourceRow, CurrentPosition, TypePosition - 1 + LengthStartOfType));
			
			RemainsOfRow = Mid(SourceRow, CurrentPosition + TypePosition + LengthStartOfType - 1);
			CurrentPosition = CurrentPosition + TypePosition + LengthStartOfType - 1;
			
			EndOfTypePosition = Find(RemainsOfRow, EndOfType);
			If EndOfTypePosition = 0 Then
				Break;
			EndIf;
			
			TypeName = Left(RemainsOfRow, EndOfTypePosition - 1);
			MapReplace = MapReplaceOfRef.Get(TypeName);
			If MapReplace = Undefined Then
				TypePosition = Find(RemainsOfRow, StartOfType);
				Continue;
			EndIf;
			
			WriteFlow.Write(TypeName);
			WriteFlow.Write(EndOfType);
			
			SourceRowXML = Mid(RemainsOfRow, EndOfTypePosition + LengthEndOfType, 36);
			
			FindRowXML = MapReplace.Get(SourceRowXML);
			
			If FindRowXML = Undefined Then
				WriteFlow.Write(SourceRowXML);
			Else
				WriteFlow.Write(FindRowXML);
			EndIf;
			
			CurrentPosition = CurrentPosition + EndOfTypePosition - 1 + LengthEndOfType + 36;
			RemainsOfRow = Mid(RemainsOfRow, EndOfTypePosition + LengthEndOfType + 36);
			TypePosition = Find(RemainsOfRow, StartOfType);
			
		EndDo;
		
		If RemainsOfRow <> Undefined Then
			WriteFlow.WriteLine(RemainsOfRow);
		Else
			WriteFlow.WriteLine(SourceRow);
		EndIf;
		
		SourceRow = ReadFlow.ReadLine();
		
	EndDo;
	
	ReadFlow.Close();
	WriteFlow.Close();
	
	FileName = TempFile;
	
EndProcedure

#EndRegion

#EndRegion

#Region FillingMetadata

// Procedure fills in the selection settings on the first start
//
Procedure FillFilterUserSettings()
	
	CurrentUser = Users.CurrentUser();
	
	DriveServer.SetStandardFilterSettings(CurrentUser);
	
EndProcedure

// Procedure fills in contracts forms from layout.
//
Procedure FillContractsForms()
	
	BeginTransaction();
	Try
		PurchaseAndSaleContractTemplate = Catalogs.ContractForms.GetTemplate("PurchaseAndSaleContractTemplate");
		
		Templates = New Array(1);
		Templates[0] = PurchaseAndSaleContractTemplate;
		
		LayoutNames = New Array(1);
		LayoutNames[0] = "PurchaseAndSaleContractTemplate";
		
		Forms = New Array(1);
		Forms[0] = Catalogs.ContractForms.PurchaseAndSaleContract.Ref.GetObject();
		
		Iterator = 0;
		While Iterator < Templates.Count() Do 
			
			ContractTemplate = Catalogs.ContractForms.GetTemplate(LayoutNames[Iterator]);
			
			TextHTML = ContractTemplate.GetText();
			Attachments = New Structure;
			
			EditableParametersNumber = StrOccurrenceCount(TextHTML, "{FilledField");
			
			Forms[Iterator].EditableParameters.Clear();
			ParameterNumber = 1;
			While ParameterNumber <= EditableParametersNumber Do 
				NewRow = Forms[Iterator].EditableParameters.Add();
				NewRow.Presentation = "{FilledField" + ParameterNumber + "}";
				NewRow.ID = "parameter" + ParameterNumber;
				
				ParameterNumber = ParameterNumber + 1;
			EndDo;
			
			Cases = New Array;
			Cases.Add(Undefined);
			Cases.Add("nominative");
			Cases.Add("genitive");
			Cases.Add("dative");
			Cases.Add("accusative");
			Cases.Add("instrumental");
			Cases.Add("prepositional");
			
			For Each ParameterEnumeration IN Enums.ContractsWithCounterpartiesTemplatesParameters Do
				
				For Each Case IN Cases Do
					If Case = Undefined Then
						PresentationCase = "";
					Else
						PresentationCase = " (" + Case + ")";
					EndIf;
					
					Parameter = "{" + String(ParameterEnumeration) + PresentationCase + "}";
					OccurrenceCount = StrOccurrenceCount(TextHTML, Parameter);
					For ParameterNumber = 1 To OccurrenceCount Do
						If ParameterNumber = 1 Then
							Presentation = "{" + String(ParameterEnumeration) + PresentationCase + "%deleteSymbols%" + "}";
							ID = "infoParameter" + String(ParameterEnumeration) + ParameterNumber;
						Else
							Presentation = "{" + String(ParameterEnumeration) + ParameterNumber + PresentationCase + "}";
							ID = "infoParameter" + String(ParameterEnumeration) + ParameterNumber;
						EndIf;
						
						FirstOccurence = Find(TextHTML, Parameter);
						
						TextHTML = Left(TextHTML, FirstOccurence - 1) + Presentation + Mid(TextHTML, FirstOccurence + StrLen(Parameter));
						
						NewRow = Forms[Iterator].InfobaseParameters.Add();
						NewRow.Presentation = StrReplace(Presentation, "%deleteSymbols%", "");
						NewRow.ID = ID;
						NewRow.Parameter = ParameterEnumeration;
						
					EndDo;
					TextHTML = StrReplace(TextHTML, "%deleteSymbols%", "");
				EndDo;
			EndDo;
			
			FormattedDocumentStructure = New Structure;
			FormattedDocumentStructure.Insert("HTMLText", TextHTML);
			FormattedDocumentStructure.Insert("Attachments", Attachments);
			
			Forms[Iterator].Form = New ValueStorage(FormattedDocumentStructure);
			Forms[Iterator].PredefinedFormTemplate = LayoutNames[Iterator];
			Forms[Iterator].EditableParametersNumber = EditableParametersNumber;
			Forms[Iterator].Write();
			
			Iterator = Iterator + 1;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		MessageText = DetailErrorDescription(ErrorInfo());
		WriteLogEvent("en = 'Filling contract forms'; ru = 'Заполнение форм договоров';pl = 'Wypełnianie formularzy kontraktu';es_ES = 'Rellenar los formularios del contrato';es_CO = 'Rellenar los formularios del contrato';tr = 'Sözleşme formları dolduruluyor';it = 'Compilazione moduli del contratto';de = 'Vertragsformulare auffüllen'", EventLogLevel.Error,,, MessageText);
		
	EndTry;
	
EndProcedure

Procedure FillPredefinedPeripheralsDrivers() Export
	EquipmentManagerServerCallOverridable.RefreshSuppliedDrivers();
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure UpdateAdditionalInformation() Export
	PropertyManagerInternal.SetUsageFlagValue();
EndProcedure

Procedure SetNeedKitProcessingInfobaseUpdate() Export
	
	If Constants.KitProcessingUpdateWasCompleted.Get() = False Then
		
		If Constants.DriveTrade.Get()
			Or Constants.UseKitProcessing.Get() = False Then
			
			Constants.KitProcessingUpdateWasCompleted.Set(True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure UpdateContractForms() Export
	
	BeginTransaction();
	Try
	
		Selection = Catalogs.ContractForms.Select();
		
		While Selection.Next() Do
			
			ReceivedObject = Selection.GetObject();
			ReceivedObject.InfobaseParameters.Clear();
			Form = ReceivedObject.Form.Get();
			
			TextHTML = Form.HTMLText;
			
			Cases = New Array;
			Cases.Add(Undefined);
			Cases.Add("nominative");
			Cases.Add("genitive");
			Cases.Add("dative");
			Cases.Add("accusative");
			Cases.Add("instrumental");
			Cases.Add("prepositional");
			
			For Each ParameterEnumeration IN Enums.ContractsWithCounterpartiesTemplatesParameters Do
				
				For Each Case IN Cases Do
					If Case = Undefined Then
						PresentationCase = "";
					Else
						PresentationCase = " (" + Case + ")";
					EndIf;
					
					Parameter = "{" + String(ParameterEnumeration) + PresentationCase + "}";
					OccurrenceCount = StrOccurrenceCount(TextHTML, Parameter);
					For ParameterNumber = 1 To OccurrenceCount Do
						If ParameterNumber = 1 Then
							Presentation = "{" + String(ParameterEnumeration) + PresentationCase + "%deleteSymbols%" + "}";
							ID = "infoParameter" + String(ParameterEnumeration) + ParameterNumber;
						Else
							Presentation = "{" + String(ParameterEnumeration) + ParameterNumber + PresentationCase + "}";
							ID = "infoParameter" + String(ParameterEnumeration) + ParameterNumber;
						EndIf;
						
						FirstOccurence = Find(TextHTML, Parameter);
						
						TextHTML = Left(TextHTML, FirstOccurence - 1) + Presentation + Mid(TextHTML, FirstOccurence + StrLen(Parameter));
						
						NewRow = ReceivedObject.InfobaseParameters.Add();
						NewRow.Presentation = StrReplace(Presentation, "%deleteSymbols%", "");
						NewRow.ID = ID;
						NewRow.Parameter = ParameterEnumeration;
						
					EndDo;
					TextHTML = StrReplace(TextHTML, "%deleteSymbols%", "");
				EndDo;
			EndDo;
			
			AdditionalAttributesOwners = New Array;
			AdditionalAttributesOwners.Add(Documents.SalesOrder.EmptyRef());
			AdditionalAttributesOwners.Add(Documents.Quote.EmptyRef());
			AdditionalAttributesOwners.Add(Catalogs.CounterpartyContracts.EmptyRef());
			AdditionalAttributesOwners.Add(Catalogs.Counterparties.EmptyRef());
			
			For Each Item IN AdditionalAttributesOwners Do
				AdditionalAttributes = PropertyManager.ObjectProperties(Item, True, False);
				
				For Each Attribute IN AdditionalAttributes Do
					Parameter = "{" + String(Attribute.Description) + "}";
					OccurrenceCount = StrOccurrenceCount(TextHTML, Parameter);
					For ParameterNumber = 1 To OccurrenceCount Do
						If ParameterNumber = 1 Then
							Presentation = "{" + String(Attribute.Description) + "}";
						Else
							Presentation = "{" + String(Attribute.Description) + ParameterNumber + "}";
						EndIf;
						
						ParameterNamePresentation = StrReplace(Attribute.Description, " ", "");
						ParameterNamePresentation = StrReplace(ParameterNamePresentation, "(", "");
						ParameterNamePresentation = StrReplace(ParameterNamePresentation, ")", "");
						ID = "additionalParameter" + ParameterNamePresentation + ParameterNumber;
						
						FirstOccurence = Find(TextHTML, Parameter);
						
						TextHTML = Left(TextHTML, FirstOccurence - 1) + Presentation + Mid(TextHTML, FirstOccurence + StrLen(Parameter));
						
						NewRow = ReceivedObject.InfobaseParameters.Add();
						NewRow.Presentation = StrReplace(Presentation, "%deleteSymbols%", "");
						NewRow.ID = ID;
						NewRow.Parameter = Attribute;
						
					EndDo;
					TextHTML = StrReplace(TextHTML, "%deleteSymbols%", "");
				EndDo;
			EndDo;
			
			FormattedDocumentStructure = New Structure;
			FormattedDocumentStructure.Insert("HTMLText", TextHTML);
			FormattedDocumentStructure.Insert("Attachments", New Structure);
			
			ReceivedObject.Form = New ValueStorage(FormattedDocumentStructure);
			ReceivedObject.Write();
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
	EndTry;
	
EndProcedure

Procedure CheckCatalogItemsCodesForUniqueness(Catalog, Item = Undefined, Shift = Undefined) Export
	
	
	
EndProcedure

Procedure FillContractCurrencyRates() Export
	
	QueryText = "";
	
	For Each DocumentMetadata In Metadata.Documents Do
		
		If DocumentMetadata.Attributes.Find("ContractCurrencyExchangeRate") = Undefined
			Or DocumentMetadata.Attributes.Find("ContractCurrencyMultiplicity") = Undefined Then
			
			Continue;
		EndIf;
		
		If Not IsBlankString(QueryText) Then
			QueryText = QueryText + DriveClientServer.GetQueryUnion();
		EndIf;
		
		QueryText = QueryText + 
		"SELECT
		|	DocumentTable.Ref AS Ref
		|FROM
		|	&DocumentTable AS DocumentTable
		|WHERE
		|	(DocumentTable.ContractCurrencyExchangeRate = 0
		|			OR DocumentTable.ContractCurrencyMultiplicity = 0)";
		
		QueryText = StrReplace(QueryText, "&DocumentTable", DocumentMetadata.FullName());
		
	EndDo;
	
	If IsBlankString(QueryText) Then 
		Return;
	EndIf;
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocumentObject = Selection.Ref.GetObject();
		If DocumentObject <> Undefined Then
			
			DocumentObject.ExchangeRate = ?(DocumentObject.ExchangeRate = 0, 1, DocumentObject.ExchangeRate);
			DocumentObject.Multiplicity = ?(DocumentObject.Multiplicity = 0, 1, DocumentObject.Multiplicity);
			
			FillContractCurrencyExchangeRateAndMultiplicity(DocumentObject);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function FillNewOrderStatusesStructure() Export
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("CatalogEmptyRef");
	ReturnStructure.Insert("OrderEmptyRef");
	ReturnStructure.Insert("ConstantNameCompletionStatus");
	ReturnStructure.Insert("ConstantNameInProgressStatus");
	
	Return ReturnStructure;
	
EndFunction

Procedure FillNewOrderStatuses(StatusesStructure) Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	CatalogEmptyRef = StatusesStructure.CatalogEmptyRef;
	OrderEmptyRef = StatusesStructure.OrderEmptyRef;
	ConstantNameCompletionStatus = StatusesStructure.ConstantNameCompletionStatus;
	ConstantNameInProgressStatus = StatusesStructure.ConstantNameInProgressStatus;
	
	CatalogMetadata = CatalogEmptyRef.Metadata();
	CatalogName = CatalogMetadata.Name;
	CatalogManager = Catalogs[CatalogName];
	
	InProgressStatus = CatalogEmptyRef;
	CompletedStatus = CatalogEmptyRef;
	OpenStatus = CatalogManager.Open;
	OrderStatus = Common.ObjectAttributeValue(OpenStatus, "OrderStatus");
	
	// Open status
	
	If Not ValueIsFilled(OrderStatus) Then
		
		OpenStatusObject = OpenStatus.GetObject();
		OpenStatusObject.OrderStatus = Enums.OrderStatuses.Open;
		
		Try
			
			InfobaseUpdate.WriteObject(OpenStatusObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog item ""%1"". Details: %2'; ru = 'Не удалось записать элемент справочника ""%1"". Подробнее: %2';pl = 'Nie można zapisać elementu katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el artículo del catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el artículo del catálogo ""%1"". Detalles: %2';tr = '""%1"" katalog öğesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare l''elemento ""%1"" del catalogo. Dettagli: %2';de = 'Fehler beim Speichern der Katalogposition ""%1"". Details: %2'", DefaultLanguageCode),
				OpenStatus,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				CatalogMetadata,
				,
				ErrorDescription);
			
		EndTry;
		
	EndIf;
	
	// Completed status
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	CatalogStatuses.Ref AS Ref
	|FROM
	|	&CatalogStatuses AS CatalogStatuses
	|WHERE
	|	CatalogStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
	
	Query.Text = StrReplace(Query.Text, "&CatalogStatuses", "Catalog." + CatalogName);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		CompletedStatusObject = CatalogManager.CreateItem();
		CompletedStatusObject.Description = NStr("en = 'Completed'; ru = 'Завершен';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'");
		CompletedStatusObject.Color = New ValueStorage(Metadata.StyleItems.OrderIsClosed.Value);
		CompletedStatusObject.OrderStatus = Enums.OrderStatuses.Completed;
		
		Try
			
			InfobaseUpdate.WriteObject(CompletedStatusObject);
			CompletedStatus = CompletedStatusObject.Ref;
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog item ""%1"". Details: %2'; ru = 'Не удалось записать элемент справочника ""%1"". Подробнее: %2';pl = 'Nie można zapisać elementu katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el artículo del catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el artículo del catálogo ""%1"". Detalles: %2';tr = '""%1"" katalog öğesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare l''elemento ""%1"" del catalogo. Dettagli: %2';de = 'Fehler beim Speichern der Katalogposition ""%1"". Details: %2'", DefaultLanguageCode),
				CompletedStatusObject,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				CatalogMetadata,
				,
				ErrorDescription);
			
		EndTry;
		
	Else
		
		Selection = Result.Select();
		If Selection.Next() Then
			CompletedStatus = Selection.Ref;
		EndIf;
		
	EndIf;
	
	// In progress status
	
	Query.Text =
	"SELECT TOP 1
	|	CatalogStatuses.Ref AS Ref
	|FROM
	|	&CatalogStatuses AS CatalogStatuses
	|WHERE
	|	CatalogStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
	
	Query.Text = StrReplace(Query.Text, "&CatalogStatuses", "Catalog." + CatalogName);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		InProgressStatusObject = CatalogManager.CreateItem();
		InProgressStatusObject.Description = NStr("en = 'In progress'; ru = 'В работе';pl = 'W toku';es_ES = 'En progreso';es_CO = 'En progreso';tr = 'İşlemde';it = 'In corso';de = 'In Bearbeitung'");
		InProgressStatusObject.Color = New ValueStorage(WebColors.MediumSeaGreen);
		InProgressStatusObject.OrderStatus = Enums.OrderStatuses.InProcess;
		
		Try
			
			InfobaseUpdate.WriteObject(InProgressStatusObject);
			InProgressStatus = InProgressStatusObject.Ref;
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save catalog item ""%1"". Details: %2'; ru = 'Не удалось записать элемент справочника ""%1"". Подробнее: %2';pl = 'Nie można zapisać elementu katalogu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el artículo del catálogo ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el artículo del catálogo ""%1"". Detalles: %2';tr = '""%1"" katalog öğesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare l''elemento ""%1"" del catalogo. Dettagli: %2';de = 'Fehler beim Speichern der Katalogposition ""%1"". Details: %2'", DefaultLanguageCode),
				InProgressStatusObject,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				CatalogMetadata,
				,
				ErrorDescription);
			
		EndTry;
		
	Else
		
		Selection = Result.Select();
		If Selection.Next() Then
			InProgressStatus = Selection.Ref;
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Constants[ConstantNameCompletionStatus].Get()) And ValueIsFilled(CompletedStatus) Then
		Constants[ConstantNameCompletionStatus].Set(CompletedStatus);
	EndIf;
	
	If Not ValueIsFilled(Constants[ConstantNameInProgressStatus].Get()) And ValueIsFilled(InProgressStatus) Then
		Constants[ConstantNameInProgressStatus].Set(InProgressStatus);
	EndIf;
	
EndProcedure

// begin Drive.FullVersion

Procedure SetUseByProductsAccountingStartingDate() Export
	
	If ValueIsFilled(Constants.UseByProductsAccountingStartingFrom.Get()) Then
		Return;
	EndIf;
	
	CurDate = CurrentSessionDate();
	MidDay = BegOfDay(CurDate) + 12*60*60;
	StartDate = ?(CurDate < MidDay, BegOfDay(CurDate), EndOfDay(CurDate) + 1);
	
	Constants.UseByProductsAccountingStartingFrom.Set(StartDate);
	
EndProcedure

Procedure ReplaceDeletedRolesInProductionAccessGroupProfiles() Export
	
	UseProductionPlanningArray = New Array;
	UseProductionPlanningArray.Add("UseFunctionalityProductionPlanning");
	
	RolesMap = New Map;
	
	RolesMap.Insert("? AddEditProductionPlanning", UseProductionPlanningArray);
	RolesMap.Insert("? UseReportProductionSchedule", UseProductionPlanningArray);
	RolesMap.Insert("? UseDataProcessorProductionSchedulePlanning", UseProductionPlanningArray);
	RolesMap.Insert("? UseDataProcessorProductionOrderQueueManagement", UseProductionPlanningArray);
	RolesMap.Insert("? UseDataProcessorWorkInProgressManagement", UseProductionPlanningArray);
	RolesMap.Insert("? UseDataProcessorWorkCentersWorkplace", UseProductionPlanningArray);
	
	AddEditDocumentsKitOrderArray = New Array;
	AddEditDocumentsKitOrderArray.Add("AddEditDocumentsKitOrder");
	
	RolesMap.Insert("? UseReportKitOrderStatement", AddEditDocumentsKitOrderArray);
	
	AccessManagement.ReplaceRolesInProfiles(RolesMap);
	
EndProcedure

// end Drive.FullVersion

Procedure ReplaceDeletedRolesInAccessGroupProfiles() Export
	
	RolesMap = New Map;
	ReplaceablRoles = New Array;
	ReplaceablRoles.Add("SubsystemAccounting");
	
	RolesMap.Insert("? SubsystemAccounitng", ReplaceablRoles);
	
	AccessManagement.ReplaceRolesInProfiles(RolesMap);
	
EndProcedure

#EndRegion

#Region RevisionOfWorkingWithCurrencies

Procedure FillContractCurrencyExchangeRateAndMultiplicity(DocObject) Export
	
	Try
		
		DocObject.ContractCurrencyExchangeRate = DocObject.ExchangeRate;
		DocObject.ContractCurrencyMultiplicity = DocObject.Multiplicity;
		DocObject.DataExchange.Load = True;
		DocObject.Write(DocumentWriteMode.Write);
		
	Except
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
			DocObject.Ref,
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Error,
			DocObject.Metadata(),
			,
			ErrorDescription);
		
	EndTry;
	
EndProcedure

Procedure VATRegistersEntriesReGeneration(DocObject) Export
	
	BeginTransaction();
	
	Try
		
		DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
		If TypeOf(DocObject) = Type("DocumentObject.ShiftClosure") Then
			DocObject.AddAttributesToAdditionalPropertiesForPosting(DocObject.AdditionalProperties);
		EndIf;
		
		DocMetaData = DocObject.Metadata();
		
		Documents[DocMetaData.Name].InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
		
		If DocMetaData.RegisterRecords.Contains(Metadata.AccumulationRegisters.VATIncurred)
			And DocObject.AdditionalProperties.TableForRegisterRecords.Property("TableVATIncurred") Then
			
			DriveServer.ReflectVATIncurred(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.VATIncurred);
			
		EndIf;
		
		If DocMetaData.RegisterRecords.Contains(Metadata.AccumulationRegisters.VATInput)
			And DocObject.AdditionalProperties.TableForRegisterRecords.Property("TableVATInput") Then
			
			DriveServer.ReflectVATInput(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.VATInput);
			
		EndIf;
		
		If DocMetaData.RegisterRecords.Contains(Metadata.AccumulationRegisters.VATOutput)
			And DocObject.AdditionalProperties.TableForRegisterRecords.Property("TableVATOutput") Then
			
			DriveServer.ReflectVATOutput(DocObject.AdditionalProperties, DocObject.RegisterRecords, False);
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.VATOutput);
			
		EndIf;
		
		DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
		
		CommitTransaction();
		
	Except
		
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
			
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
			DocObject.Ref,
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Error,
			DocObject.Metadata(),
			,
			ErrorDescription);
		
	EndTry;
	
EndProcedure

#EndRegion

#EndRegion