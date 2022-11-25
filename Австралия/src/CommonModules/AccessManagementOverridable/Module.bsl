#Region Public

// Fills access kinds used in access restrictions.
// Note: the Users and ExternalUsers access kinds are predefined, but you can remove them from the 
// AccessKinds list if you do not need them for access restriction.
//
// Parameters:
//  AccessKinds - ValueTable - a table with the following columns:
//   * Name - String - a name used in description of the supplied access group profiles and RLS 
//                                       texts.
//   * Presentation - String - presents an access kind in profiles and access groups.
//   * ValuesType - Type - an access value reference type, for example, Type("CatalogRef.Products").
//                                       
//   * ValuesGroupsType - Type - an access value group reference type, for example, Type("CatalogRef.
//                                       ProductsAccessGroups").
//   * MultipleValuesGroups - Boolean - True indicates that you can select multiple value groups 
//                                       (Products access group) for an access value (Products).
//
// Example:
//  1. To set access rights by companies:
//  AccessKind = AccessKinds.Add(),
//  AccessKind.Name = "Companies",
//  AccessKind.Presentation = NStr("en = 'Companies'",)
//  AccessKind.ValuesType = Type("CatalogRef.Companies"),
//
//  2. To set access rights by partner groups:
//  AccessKind = AccessKinds.Add(),
//  AccessKind.Name = "PartnersGroups",
//  AccessKind.Presentation = NStr("en = 'Partner groups'"),
//  AccessKind.ValuesType = Type("CatalogRef.Partners"),
//  AccessKind.ValuesGroupsType = Type("CatalogRef.PartnersAccessGroups"),
//
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "CashAccounts";
	AccessKind.Presentation    = NStr("en = 'Cash funds'; ru = 'Кассы';pl = 'Kasy';es_ES = 'Fondos en efectivo';es_CO = 'Fondos en efectivo';tr = 'Nakit para';it = 'Fondi di liquidità';de = 'Barmittel'");
	AccessKind.ValuesType      = Type("CatalogRef.CashAccounts");
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name             = "CounterpartiesGroup";
	AccessKind.Presentation     = NStr("en = 'Counterparty groups'; ru = 'Группы контрагентов';pl = 'Grupy kontrahentów';es_ES = 'Grupos de la contraparte';es_CO = 'Grupos de la contraparte';tr = 'Cari hesap grupları';it = 'Gruppi delle controparti';de = 'Geschäftspartnergruppen'");
	AccessKind.ValuesType       = Type("CatalogRef.Counterparties");
	AccessKind.ValuesGroupsType = Type("CatalogRef.CounterpartiesAccessGroups");
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name             = "FilesGroup";
	AccessKind.Presentation     = NStr("en = 'File groups'; ru = 'Группы файлов';pl = 'Grupy plików';es_ES = 'Grupos de archivos';es_CO = 'Grupos de archivos';tr = 'Dosya grupları';it = 'Gruppi file';de = 'Dateigruppen'");
	AccessKind.ValuesType       = Type("CatalogRef.Files");
	AccessKind.ValuesGroupsType = Type("CatalogRef.FilesAccessGroups");
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "Companies";
	AccessKind.Presentation = NStr("en = 'Companies'; ru = 'Организации';pl = 'Firmy';es_ES = 'Empresas';es_CO = 'Empresas';tr = 'İş yerleri';it = 'Aziende';de = 'Firmen'");
	AccessKind.ValuesType = Type("CatalogRef.Companies");
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "BusinessUnits";
	AccessKind.Presentation = NStr("en = 'Business units'; ru = 'Структурные единицы';pl = 'Jednostki biznesowe';es_ES = 'Unidades empresariales';es_CO = 'Unidades de negocio';tr = 'Departmanlar';it = 'Business Units';de = 'Abteilungen'");
	AccessKind.ValuesType = Type("CatalogRef.BusinessUnits");
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name             = "ProductGroups";
	AccessKind.Presentation     = NStr("en = 'Product groups for external users'; ru = 'Группы номенклатуры для внешних пользователей';pl = 'Grupy produktów dla użytkowników zewnętrznych';es_ES = 'Grupos de productos para usuarios externos';es_CO = 'Grupos de productos para usuarios externos';tr = 'Harici kullanıcılar için ürün grupları';it = 'Gruppi articolo per utenti esterni';de = 'Produktgruppen für externe Benutzer'");
	AccessKind.ValuesType       = Type("CatalogRef.ProductAccessGroupsForExternalUsers");
	
EndProcedure

// Allows you to specify lists whose metadata objects contain description of the logic for access 
// restriction in the manager modules or the overridable module.
//
// In manager modules of the specified lists, there must be a handler procedure, to which the 
// following parameters are passed.
// 
//  Restriction - Structure - with the following properties:
//    * Text - String - access restriction for users.
//                                            If the string is blank, access is granted.
//    * TextForExternalUsers - String - access restriction for external users.
//                                            If the string is blank, access denied.
//    * ByOwnerWithoutAccessKeysRecord - Undefined - define automatically.
//                                        - Boolean - if False, always write access keys. If True, 
//                                            do not write access keys, but use owner access keys 
//                                            (the restriction must be by the owner object only).
//                                            
///   * ByOwnerWithoutAccessKeysRecordForExternalUsers - Undefined, Boolean - see
//                                            description of the previous parameter.
//
// The following is an example procedure for a manager module.
//
//// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
//Procedure OnFillAccessRestriction(Restriction) Export
//	
//	Restriction.Text =
//	"AllowReadEdit
//	|WHERE
//	|	ValueAllowed(Company)
//	|	And ValueAllowed(Counterparty)";
//	
//EndProcedure
//
// Parameters:
//  Lists - Map - lists with access restriction:
//             * Key - MetadataObject - a list with access restriction.
//             * Value - Boolean - True - a restriction text in the manager module.
//                                 - False - a restriction text in the overridable
//                module in the OnFillAccessRestriction procedure.
//
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	
	
EndProcedure

// Fills descriptions of supplied access group profiles and overrides update parameters of profiles 
// and access groups.
//
// To generate the procedure code automatically, it is recommended that you use the developer tools 
// from the Access management subsystem.
//
// Parameters:
//  ProfilesDetails - Array - add access group profile descriptions (Structure).
//                        See the structure properties in AccessManagement. NewAccessGroupsProfileDetails.
//
//  UpdateParameters - Structure - contains the following properties:
//   * UpdateChangedProfiles - Boolean - the initial value is True.
//   * DenyProfilesChange - Boolean - the initial value is True.
//       If False, the supplied profiles can not only be viewed but also edited.
//   * UpdatingAccessGroups - Boolean - the default value is True.
//   * UpdatingAccessGroupsWithObsoleteSettings - Boolean - the default value is False.
//       If True, the value settings made by the administrator for the access kind, which was 
//       deleted from the profile, are also deleted from the access groups.
//
// Example:
//  ProfileDetails = AccessManagement.NewAccessGroupProfileDetails(),
//  ProfileDetails.Name = "Manager",
//  ProfileDetails.ID = "75fa0ecb-98aa-11df-b54f-e0cb4ed5f655";
//  ProfileDetails.Description = NStr("en = 'Sales representative'", Metadata.DefaultLanguage.LanguageCode);
//  ProfileDetails.Roles.Add("StartWebClient");
//  ProfileDetails.Roles.Add("StartThinClient");
//  ProfileDetails.Roles.Add("BasicSSLRights");
//  ProfileDetails.Roles.Add("Subsystem_Sales");
//  ProfileDetails.Roles.Add("AddEditCustomersDocuments");
//  ProfileDetails.Roles.Add("ViewReportPurchaseLedger");
//  ProfilesDetails.Add(ProfileDetails);
//
Procedure OnFillSuppliedAccessGroupProfiles(ProfilesDetails, UpdateParameters) Export
	
#Region Sales
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Sales" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "Sales";
	ProfileDescription.ID = "76337576-bff4-11df-9174-e0cb4ed5f4c3";	
	ProfileDescription.Description = NStr("en = 'Sales'; ru = 'Продажи';pl = 'Sprzedaż';es_ES = 'Ventas';es_CO = 'Ventas';tr = 'Satış';it = 'Vendite';de = 'Verkäufe'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to operate with the Sales section.'; ru = 'Под профилем осуществляется работа с разделом Продажи.';pl = 'Używaj tego profilu do pracy z sekcją Sprzedaż.';es_ES = 'Utilizar este perfil para operar con la sección de Ventas.';es_CO = 'Utilizar este perfil para operar con la sección de Ventas.';tr = 'Satış bölümü ile çalışmak için bu profili kullan.';it = 'Utilizzare questo profilo per operare con la sezione Vendite.';de = 'Dieses Profil für Operationen mit dem Verkaufsabschnitt verwenden.'");
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("PrintFormsEdit");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	ProfileDescription.Roles.Add("DataSynchronizationSetting");
	ProfileDescription.Roles.Add("AddEditBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditReportsOptions");
	ProfileDescription.Roles.Add("AddEditIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddEditCatalogIndividuals");
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("EditAdditionalInfo");
	ProfileDescription.Roles.Add("EditPrintFormTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("ReadReportOptions");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("AddEditNotifications");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("ViewEventLog");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInfo");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangeLog");
	ProfileDescription.Roles.Add("ReadCurrencyRates");
	ProfileDescription.Roles.Add("AddEditProducts");
	ProfileDescription.Roles.Add("AddEditPersonalMessagesTemplates");
	ProfileDescription.Roles.Add("AddEditInteractions");
	ProfileDescription.Roles.Add("AddEditInformationRegisterPrintFormsArchivingSettings");
	
	If Not CommonCached.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("StartThickClient");
	EndIf;
	
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("AddEditEventsAndTasks");
	ProfileDescription.Roles.Add("AddEditCounterparties");
	ProfileDescription.Roles.Add("AddEditInventoryMovements");
	ProfileDescription.Roles.Add("AddEditBankAccounts");
	ProfileDescription.Roles.Add("ReadDocumentsByBankAndPettyCash");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	ProfileDescription.Roles.Add("AddEditReportBulkEmails");
	ProfileDescription.Roles.Add("ReadReportBulkEmails");
	ProfileDescription.Roles.Add("AddEditJobs");
	ProfileDescription.Roles.Add("ReadTasks");
	ProfileDescription.Roles.Add("EditDocumentPrices");
	
	// Work with files
	ProfileDescription.Roles.Add("FileOperations");
	
	// Sales
	ProfileDescription.Roles.Add("AddEditCatalogAutomaticDiscountTypes");
	ProfileDescription.Roles.Add("AddEditCatalogBatchSettings");
	ProfileDescription.Roles.Add("AddEditCatalogBatchTrackingPolicies");
	ProfileDescription.Roles.Add("AddEditCatalogBusinessUnits");
	ProfileDescription.Roles.Add("AddEditDocumentsActualSalesVolume");
	ProfileDescription.Roles.Add("UseDataProcessorClosingInvoiceProcessing");
	ProfileDescription.Roles.Add("UseReportClosingInvoices");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterActualSalesVolume");
	ProfileDescription.Roles.Add("AddEditCatalogCashierWorkplaceSettings");
	ProfileDescription.Roles.Add("AddEditCatalogCashRegisters");
	ProfileDescription.Roles.Add("AddEditCatalogCells");
	ProfileDescription.Roles.Add("AddEditCatalogContactPersons");
	ProfileDescription.Roles.Add("AddEditCatalogContainerTypes");
	ProfileDescription.Roles.Add("AddEditCatalogCounterparties");
	ProfileDescription.Roles.Add("AddEditCatalogCounterpartyContracts");
	ProfileDescription.Roles.Add("AddEditCatalogDiscountCards");
	ProfileDescription.Roles.Add("AddEditCatalogDiscountCardsTemplates");
	ProfileDescription.Roles.Add("AddEditCatalogDiscountCardTypes");
	ProfileDescription.Roles.Add("AddEditCatalogDiscountConditions");
	ProfileDescription.Roles.Add("AddEditCatalogDiscountTypes");
	ProfileDescription.Roles.Add("AddEditCatalogEstimatesTemplates");
	ProfileDescription.Roles.Add("AddEditCatalogIncoterms");
	ProfileDescription.Roles.Add("AddEditCatalogJobAndEventStatuses");
	ProfileDescription.Roles.Add("AddEditCatalogLabelsAndTagsTemplates");
	ProfileDescription.Roles.Add("AddEditCatalogPaymentCardTypes");
	ProfileDescription.Roles.Add("AddEditCatalogPaymentMethods");
	ProfileDescription.Roles.Add("AddEditCatalogPaymentTermsTemplates");
	ProfileDescription.Roles.Add("AddEditCatalogPOSTerminals");
	ProfileDescription.Roles.Add("AddEditCatalogPriceGroups");
	ProfileDescription.Roles.Add("AddEditCatalogPriceLists");
	ProfileDescription.Roles.Add("AddEditCatalogPriceTypes");
	ProfileDescription.Roles.Add("AddEditCatalogProducts");
	ProfileDescription.Roles.Add("AddEditCatalogProductsBatches");
	ProfileDescription.Roles.Add("AddEditCatalogProductsCategories");
	ProfileDescription.Roles.Add("AddEditCatalogProductsCharacteristics");
	ProfileDescription.Roles.Add("AddEditCatalogProjects");
	ProfileDescription.Roles.Add("AddEditCatalogQuotationStatuses");
	ProfileDescription.Roles.Add("AddEditCatalogSalesGoalSettings");
	ProfileDescription.Roles.Add("AddEditCatalogSalesOrderStatuses");
	ProfileDescription.Roles.Add("AddEditCatalogSalesTaxRates");
	ProfileDescription.Roles.Add("AddEditCatalogSalesTerritories");
	ProfileDescription.Roles.Add("AddEditCatalogSerialNumbers");
	ProfileDescription.Roles.Add("AddEditCatalogSerialNumbersTemplates");
	ProfileDescription.Roles.Add("AddEditCatalogShippingAddresses");
	ProfileDescription.Roles.Add("AddEditCatalogSubscriptionPlans");
	ProfileDescription.Roles.Add("AddEditCatalogTags");
	ProfileDescription.Roles.Add("AddEditCatalogUOMClassifier");
	ProfileDescription.Roles.Add("AddEditCatalogUOM");
	ProfileDescription.Roles.Add("AddEditCatalogVATRates");
	ProfileDescription.Roles.Add("AddEditCatalogWorkOrderStatuses");
	
	
	ProfileDescription.Roles.Add("AddEditDocumentsAccountSalesFromConsignee");
	ProfileDescription.Roles.Add("AddEditDocumentsCreditNote");
	ProfileDescription.Roles.Add("AddEditDocumentsEvent");
	ProfileDescription.Roles.Add("AddEditDocumentsGoodsIssue");
	ProfileDescription.Roles.Add("AddEditDocumentsPackingSlip");
	ProfileDescription.Roles.Add("AddEditDocumentsPricing");
	ProfileDescription.Roles.Add("AddEditDocumentsProductReturn");
	ProfileDescription.Roles.Add("AddEditDocumentsQuote");
	ProfileDescription.Roles.Add("AddEditDocumentsRetailRevaluation");
	ProfileDescription.Roles.Add("AddEditDocumentsSalesInvoice");
	ProfileDescription.Roles.Add("AddEditDocumentsSalesOrder");
	ProfileDescription.Roles.Add("AddEditDocumentsSalesSlip");
	ProfileDescription.Roles.Add("AddEditDocumentsSalesTarget");
	ProfileDescription.Roles.Add("AddEditDocumentsShiftClosure");
	ProfileDescription.Roles.Add("AddEditDocumentsTaxInvoiceIssued");
	
	ProfileDescription.Roles.Add("AddEditInformationRegisterBatchTrackingPolicy");
	ProfileDescription.Roles.Add("AddEditInformationRegisterCounterpartiesGLAccounts");
	ProfileDescription.Roles.Add("AddEditInformationRegisterBarcodes");
	ProfileDescription.Roles.Add("AddEditInformationRegisterEmailLog");
	ProfileDescription.Roles.Add("AddEditInformationRegisterGeneratedDocumentsData");
	ProfileDescription.Roles.Add("AddEditInformationRegisterServiceAutomaticDiscounts");
	ProfileDescription.Roles.Add("AddEditInformationRegisterSubscriptions");
	ProfileDescription.Roles.Add("AddEditInformationRegisterVIESVATNumberValidation");
	ProfileDescription.Roles.Add("AddEditInformationRegisterQuotationKanbanStatuses");
	ProfileDescription.Roles.Add("AddEditInformationRegisterOverdraftLimits");
	
	ProfileDescription.Roles.Add("ReadAccountingRegisterAccountingJournalEntriesCompound");
	ProfileDescription.Roles.Add("ReadChartsOfAccountsMasterChartOfAccounts");
	
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsReceivable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAutomaticDiscountsApplied");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterBackorders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterCashInCashRegisters");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInvoicedNotShipped");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsShippedNotInvoiced");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventory");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryCostLayer");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryInWarehouses");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInvoicesAndOrdersPayment");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterMiscellaneousPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPackedOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPurchaseOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterQuotations");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterReservedProducts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSales");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesTarget");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesWithCardBasedDiscounts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSerialNumbers");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterThirdPartyPayments");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterVATOutput");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterVATIncurred");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterVATInput");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryDemand");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterOrdersByFulfillmentMethod");
	
	ProfileDescription.Roles.Add("ReadCatalogActivityTypes");
	ProfileDescription.Roles.Add("ReadCatalogBillsOfMaterials");
	ProfileDescription.Roles.Add("ReadCatalogBillsOfMaterialsHierarchy");
	ProfileDescription.Roles.Add("ReadCatalogCashAccounts");
	ProfileDescription.Roles.Add("ReadCatalogCompanies");
	ProfileDescription.Roles.Add("ReadCatalogContactPersonsRoles");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartiesAccessGroups");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartyContractTypes");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartySegments");
	ProfileDescription.Roles.Add("ReadCatalogHSCodes");
	ProfileDescription.Roles.Add("ReadCatalogLegalForms");
	ProfileDescription.Roles.Add("ReadCatalogLegalDocuments");
	ProfileDescription.Roles.Add("ReadCatalogProductionOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogSubcontractorOrderIssuedStatuses");
	ProfileDescription.Roles.Add("ReadCatalogWorkOrderStatuses");
	
	ProfileDescription.Roles.Add("ReadDocumentsJournalRetailDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsJournalSalesDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsJournalSalesSlips");
	
	ProfileDescription.Roles.Add("ReadDocumentsArApAdjustments");
	ProfileDescription.Roles.Add("ReadDocumentsCashVoucher");
	ProfileDescription.Roles.Add("ReadDocumentsCashReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsDebitNote");
	ProfileDescription.Roles.Add("ReadDocumentsExpenseReport");
	ProfileDescription.Roles.Add("ReadDocumentsGoodsReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsInventoryReservation");
	ProfileDescription.Roles.Add("ReadDocumentsOpeningBalanceEntry");
	ProfileDescription.Roles.Add("ReadDocumentsOnlinePayment");
	ProfileDescription.Roles.Add("ReadDocumentsOnlineReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsPaymentExpense");
	ProfileDescription.Roles.Add("ReadDocumentsPaymentReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsProductionOrder");
	ProfileDescription.Roles.Add("ReadDocumentsPurchaseOrder");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderIssued");
	ProfileDescription.Roles.Add("ReadDocumentsSupplierInvoice");
	ProfileDescription.Roles.Add("ReadDocumentsWorkOrder");
	ProfileDescription.Roles.Add("ReadDocumentsRMARequest");
	ProfileDescription.Roles.Add("ReadDocumentsTaxInvoiceReceived");
	
	ProfileDescription.Roles.Add("ReadInformationRegisterCounterpartyDuplicates");
	ProfileDescription.Roles.Add("ReadInformationRegisterExchangeRate");
	ProfileDescription.Roles.Add("ReadInformationRegisterGeneratedDocumentsData");
	ProfileDescription.Roles.Add("ReadInformationRegisterInvoicesPaymentStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderFulfillmentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderPayments"); 
	ProfileDescription.Roles.Add("ReadInformationRegisterOrdersPaymentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterPrices");
	ProfileDescription.Roles.Add("ReadInformationRegisterProductGLAccounts");
	ProfileDescription.Roles.Add("ReadInformationRegisterQuotationKanbanStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterQuotationStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterServiceAutomaticDiscounts");
	ProfileDescription.Roles.Add("ReadInformationRegisterStandardTime");
	ProfileDescription.Roles.Add("ReadInformationRegisterSubstituteGoods");
	ProfileDescription.Roles.Add("ReadInformationRegisterTasksForUpdatingStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterUsingPaymentTermsInDocuments");
	ProfileDescription.Roles.Add("ReadInformationRegisterPurchaseOrdersStates");
	ProfileDescription.Roles.Add("ReadInformationRegisterOverdraftLimits");
	
	ProfileDescription.Roles.Add("SubsystemSales");
	ProfileDescription.Roles.Add("SubsystemSettings");
	
	ProfileDescription.Roles.Add("UseDataProcessorCounterpartyDocuments");
	ProfileDescription.Roles.Add("UseDataProcessorDiscountCards");
	ProfileDescription.Roles.Add("UseDataProcessorDiscountTypes");
	ProfileDescription.Roles.Add("UseDataProcessorGenerationPriceLists");
	ProfileDescription.Roles.Add("UseDataProcessorGoodsDispatching");
	ProfileDescription.Roles.Add("UseDataProcessorOrdersClosing");
	ProfileDescription.Roles.Add("UseDataProcessorPricing");
	ProfileDescription.Roles.Add("UseDataProcessorPrintLabelsAndTags");
	ProfileDescription.Roles.Add("UseDataProcessorSearchObjectsByBarcode");
	
	ProfileDescription.Roles.Add("UseReportAccountsReceivable");
	ProfileDescription.Roles.Add("UseReportAccountsReceivableAging");
	ProfileDescription.Roles.Add("UseReportAvailableStock");
	ProfileDescription.Roles.Add("UseReportBackorders");
	ProfileDescription.Roles.Add("UseReportCashRegisterStatement");
	ProfileDescription.Roles.Add("UseReportCounterpartyContactInformation");
	ProfileDescription.Roles.Add("UseReportCreditLimits");
	ProfileDescription.Roles.Add("UseReportCustomerStatement");
	ProfileDescription.Roles.Add("UseReportGoodsConsumedToDeclare");
	ProfileDescription.Roles.Add("UseReportGoodsInvoicedNotShipped");
	ProfileDescription.Roles.Add("UseReportGoodsShippedNotInvoiced");
	ProfileDescription.Roles.Add("UseReportPackingSlips");
	ProfileDescription.Roles.Add("UseReportPOSSummary");
	ProfileDescription.Roles.Add("UseReportQuotationPipeline");
	ProfileDescription.Roles.Add("UseReportSalesOrderPayments");
	ProfileDescription.Roles.Add("UseReportSalesOrdersAnalysis");
	ProfileDescription.Roles.Add("UseReportSalesOrdersStatement");
	ProfileDescription.Roles.Add("UseReportSalesOrdersTrend");
	ProfileDescription.Roles.Add("UseReportSalesVariance");
	ProfileDescription.Roles.Add("UseReportStatementOfAccount");
	ProfileDescription.Roles.Add("UseReportSummaryOfGeneratedDocuments");
	ProfileDescription.Roles.Add("UseReportThirdPartyPayments");
	ProfileDescription.Roles.Add("UseReportDiscountsAppliedInDocument");
	ProfileDescription.Roles.Add("UseReportOrdersByFullfillment");
	ProfileDescription.Roles.Add("UseReportBankAccountsReport");
	
	ProfileDescription.Roles.Add("ViewCommonFormAppliedDiscounts");
	
	// begin Drive.FullVersion
	
	// Subcontracting
	ProfileDescription.Roles.Add("AddEditDocumentsSubcontractorInvoiceIssued");
	ProfileDescription.Roles.Add("AddEditDocumentsSubcontractorOrderReceived");
	ProfileDescription.Roles.Add("AddEditCatalogSubcontractorOrderReceivedStatuses");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterCostOfSubcontractorGoods");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterCustomerOwnedInventory");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractComponents");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractorOrdersReceived");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterWorkInProgress");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterWorkInProgressStatement");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterProductionOrders");
	ProfileDescription.Roles.Add("ReadCatalogSubcontractorOrderReceivedStatuses");
	ProfileDescription.Roles.Add("ReadCatalogCostObjects");
	ProfileDescription.Roles.Add("ReadDocumentsJournalSubcontractingDocumentsForServicesProvided");
	ProfileDescription.Roles.Add("UseDataProcessorSubcontractorOrderReceivedProcessing");
	ProfileDescription.Roles.Add("UseReportCustomerProvidedInventoryStatement");
	ProfileDescription.Roles.Add("UseReportSubcontractorOrderReceivedStatement");
	
	// end Drive.FullVersion 
	
	// EDI
	ProfileDescription.Roles.Add("EDIExchange");
	
	
	
	AddAccountingRoles(ProfileDescription);

	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("BusinessUnits", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CashAccounts", "AllAllowedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for filling the "Edit document prices (additionally)" service profile.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "EditDocumentPrices";
	ProfileDescription.ID = "76337579-bff4-11df-9174-e0cb4ed5f4c3";
	ProfileDescription.Description = NStr("en = 'Edit document prices (additionally)'; ru = 'Редактирование цен документов (дополнительно)';pl = 'Edytuj ceny dokumentów (dodatkowo)';es_ES = 'Editar los precios del documento (adicionalmente)';es_CO = 'Editar los precios del documento (adicionalmente)';tr = 'Belge fiyatlarını düzenle (ek olarak)';it = 'Modifica dei prezzi dei documenti (facoltativo)';de = 'Dokumentenpreise bearbeiten (zusätzlich)'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Service profile that allows you to edit prices in documents for managers.'; ru = 'Служебный профиль, определяющий возможность редактирования цен в документах для менеджеров.';pl = 'Profil serwisowy, który pozwala edytować ceny w dokumentach dla menedżerów.';es_ES = 'Perfil de servicio que le permite editar los precios en los documentos para directores.';es_CO = 'Perfil de servicio que le permite editar los precios en los documentos para directores.';tr = 'Yöneticiler için belgelerde fiyatları düzenlemenizi sağlayan hizmet profili.';it = 'Profilo di servizio che permette di modificare i prezzi nei documenti per i dirigenti.';de = 'Serviceprofil, mit dem Sie Preise in Dokumenten für Manager bearbeiten können.'");
	
	ProfileDescription.Roles.Add("UseDataImportFromExternalSources");
	ProfileDescription.Roles.Add("EditDocumentPrices");
	
	ProfilesDetails.Add(ProfileDescription);
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for the "Product editing (additionally)" service profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "ProductsEditing";
	ProfileDescription.ID = "76337580-bff4-11df-9174-e0cb4ed5f4c3";
	ProfileDescription.Description = NStr("en = 'Edit products (additionally)'; ru = 'Редактирование номенклатуры (дополнительно)';pl = 'Edytuj towary (dodatkowo)';es_ES = 'Editar productos (adicionalmente)';es_CO = 'Editar productos (adicionalmente)';tr = 'Ürünleri düzenle (ek olarak)';it = 'Modificare articoli (opzionale)';de = 'Produkte bearbeiten (zusätzlich)'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Service profile that allows you to edit products for managers.'; ru = 'Служебный профиль, определяющий возможность редактирования номенклатуры для менеджеров.';pl = 'Profil serwisowy, który pozwala edytować towary dla menedżerów.';es_ES = 'Perfil de servicio que le permite editar los productos para directores.';es_CO = 'Perfil de servicio que le permite editar los productos para directores.';tr = 'Yöneticiler için ürünleri düzenlemenizi sağlayan hizmet profili.';it = 'Profilo di servizio che vi permette di modificare gli articoli per i responsabili.';de = 'Serviceprofil, mit dem Sie Produkte für Manager bearbeiten können.'");
	
	ProfileDescription.Roles.Add("AddEditProducts");
	ProfileDescription.Roles.Add("AddEditAdditionalAttributesAndInfo");
	
	ProfilesDetails.Add(ProfileDescription);
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for the "Returns from customers (additionally)" service profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "ReturnsFromCustomers";
	ProfileDescription.ID = "76337581-bff4-11df-9174-e0cb4ed5f4c3";
	ProfileDescription.Description = NStr("en = 'Returns from customers (additionally)'; ru = 'Возвраты от покупателей (дополнительно)';pl = 'Zwroty od klientów (dodatkowo)';es_ES = 'Devoluciones de clientes (adicionalmente)';es_CO = 'Devoluciones de clientes (adicionalmente)';tr = 'Müşterilerden iadeler (ek olarak)';it = 'Restituzioni dai clienti (aggiuntivi)';de = 'Rückgaben von Kunden (zusätzlich)'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Service profile that allows you to work with returns from customers.'; ru = 'Служебный профиль, определяющий возможность работы с возвратами от покупателей.';pl = 'Profil serwisowy, który pozwala pracować z zwrotami od klientów.';es_ES = 'Perfil de servicio que le permite trabajar con devoluciones de clientes.';es_CO = 'Perfil de servicio que le permite trabajar con devoluciones de clientes.';tr = 'Müşterilerden gelen iadelerle çalışmanızı sağlayan hizmet profili.';it = 'Profilo di servizio che ti permette di lavorare con rendimenti da parte dei clienti.';de = 'Serviceprofil, mit dem Sie mit Rückgaben von Kunden arbeiten können.'"
	);
	
	ProfileDescription.Roles.Add("AdditionChangeOfReturnsFromBuyers");
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup", "AllDeniedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion
	
#Region Purchases

	////////////////////////////////////////////////////////////////////////////////
	// Description for the "Purchases" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "Purchases";
	ProfileDescription.ID = "76337577-bff4-11df-9174-e0cb4ed5f4c3";	
	ProfileDescription.Description = NStr("en = 'Purchases'; ru = 'Закупки';pl = 'Zakup';es_ES = 'Compras';es_CO = 'Compras';tr = 'Satın alma';it = 'Acquisti';de = 'Einkauf'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to work with the Purchases section.'; ru = 'Под профилем осуществляется работа с разделом Закупки.';pl = 'Użyj tego profilu do pracy z sekcją Zakup.';es_ES = 'Utilizar este perfil para trabajar con la sección Compras.';es_CO = 'Utilizar este perfil para trabajar con la sección Compras.';tr = 'Satın alımlar bölümü ile çalışmak için bu profili kullanın.';it = 'Utilizzare questo profilo per lavorare con la sezione acquisti.';de = 'Verwenden Sie dieses Profil, um mit dem Abschnitt Käufe zu arbeiten.'");
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("PrintFormsEdit");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	ProfileDescription.Roles.Add("DataSynchronizationSetting");
	ProfileDescription.Roles.Add("AddEditBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditReportsOptions");
	ProfileDescription.Roles.Add("AddEditIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddEditCatalogIndividuals");
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("EditAdditionalInfo");
	ProfileDescription.Roles.Add("EditPrintFormTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("ReadReportOptions");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("AddEditNotifications");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("ViewEventLog");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInfo");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangeLog");
	ProfileDescription.Roles.Add("ReadCurrencyRates");
	ProfileDescription.Roles.Add("AddEditPersonalMessagesTemplates");
	ProfileDescription.Roles.Add("AddEditInteractions");
	ProfileDescription.Roles.Add("AddEditInformationRegisterPrintFormsArchivingSettings");
	ProfileDescription.Roles.Add("ReadAdditionalReportsAndDataProcessors");
	
	If Not CommonCached.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("StartThickClient");
	EndIf;
	
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("AddEditEventsAndTasks");
	ProfileDescription.Roles.Add("AddEditAdditionalAttributesAndInfo");
	ProfileDescription.Roles.Add("EditDocumentPrices");
	ProfileDescription.Roles.Add("UseDataImportFromExternalSources");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	ProfileDescription.Roles.Add("AddEditReportBulkEmails");
	ProfileDescription.Roles.Add("AddEditJobs");
	ProfileDescription.Roles.Add("ReadTasks");
	
	// Work with files
	ProfileDescription.Roles.Add("FileOperations");
	
	// Purchases
	ProfileDescription.Roles.Add("AddEditCatalogBusinessUnits");
	ProfileDescription.Roles.Add("AddEditCatalogCells");
	ProfileDescription.Roles.Add("AddEditCatalogContainerTypes");
	ProfileDescription.Roles.Add("AddEditCatalogCounterparties");
	ProfileDescription.Roles.Add("AddEditCatalogCounterpartyContracts");
	ProfileDescription.Roles.Add("AddEditCatalogPaymentMethods");
	ProfileDescription.Roles.Add("AddEditCatalogProducts");
	ProfileDescription.Roles.Add("AddEditCatalogProductsBatches");
	ProfileDescription.Roles.Add("AddEditCatalogProductsCategories");
	ProfileDescription.Roles.Add("AddEditCatalogProductsCharacteristics");
	ProfileDescription.Roles.Add("AddEditCatalogPurchaseOrderStatuses");
	ProfileDescription.Roles.Add("AddEditCatalogSerialNumbers");
	ProfileDescription.Roles.Add("AddEditCatalogSerialNumbersTemplates");
	ProfileDescription.Roles.Add("AddEditCatalogSubcontractorOrderIssuedStatuses");
	ProfileDescription.Roles.Add("AddEditCatalogSubscriptionPlans");
	ProfileDescription.Roles.Add("AddEditCatalogSupplierPriceTypes");
	ProfileDescription.Roles.Add("AddEditCatalogSuppliersProducts");
	ProfileDescription.Roles.Add("AddEditCatalogUOMClassifier");
	ProfileDescription.Roles.Add("AddEditCatalogUOM");
	ProfileDescription.Roles.Add("AddEditCatalogContactPersons");
	ProfileDescription.Roles.Add("AddEditCatalogBatchSettings");
	ProfileDescription.Roles.Add("AddEditCatalogBatchTrackingPolicies");
	
	ProfileDescription.Roles.Add("AddEditDocumentsAccountSalesToConsignor");
	ProfileDescription.Roles.Add("AddEditDocumentsAdditionalExpenses");
	ProfileDescription.Roles.Add("AddEditDocumentsCustomsDeclaration");
	ProfileDescription.Roles.Add("AddEditDocumentsDebitNote");
	ProfileDescription.Roles.Add("AddEditDocumentsGoodsReceipt");
	ProfileDescription.Roles.Add("AddEditDocumentsLetterOfAuthority");
	ProfileDescription.Roles.Add("AddEditDocumentsPurchaseOrder");
	ProfileDescription.Roles.Add("AddEditDocumentsRequestForQuotation");
	ProfileDescription.Roles.Add("AddEditDocumentsRequisitionOrder");
	ProfileDescription.Roles.Add("AddEditDocumentsSubcontractorInvoiceReceived");
	ProfileDescription.Roles.Add("AddEditDocumentsSubcontractorOrderIssued");
	ProfileDescription.Roles.Add("AddEditDocumentsSupplierInvoice");
	ProfileDescription.Roles.Add("AddEditDocumentsSupplierQuote");
	ProfileDescription.Roles.Add("AddEditDocumentsTaxInvoiceReceived");
	
	ProfileDescription.Roles.Add("AddEditInformationRegisterCounterpartiesGLAccounts");
	ProfileDescription.Roles.Add("AddEditInformationRegisterBarcodes");
	ProfileDescription.Roles.Add("AddEditInformationRegisterReorderPointSettings");
	ProfileDescription.Roles.Add("AddEditInformationRegisterSubscriptions");
	ProfileDescription.Roles.Add("AddEditInformationRegisterCounterpartyPrices");
	ProfileDescription.Roles.Add("AddEditInformationRegisterVIESVATNumberValidation");
	ProfileDescription.Roles.Add("AddEditInformationRegisterBatchTrackingPolicy");
	ProfileDescription.Roles.Add("AddEditInformationRegisterCounterpartyDuplicates");
	ProfileDescription.Roles.Add("AddEditInformationRegisterOverdraftLimits");
	
	ProfileDescription.Roles.Add("ReadAccountingRegisterAccountingJournalEntriesCompound");
	ProfileDescription.Roles.Add("ReadChartsOfAccountsMasterChartOfAccounts");
	
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterCostOfSubcontractorGoods");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInvoicedNotReceived");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsReceivedNotInvoiced");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPurchaseOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPurchases");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterReservedProducts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSerialNumbers");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractComponents");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryInWarehouses");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsReceivable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventory");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterMiscellaneousPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterWorkOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryDemand");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterProductionOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryFlowCalendar");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryCostLayer");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterBackorders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSales");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterStockTransferredToThirdParties");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInvoicesAndOrdersPayment");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterVATInput");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterVATIncurred");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsAwaitingCustomsClearance");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPaymentCalendar");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterStockReceivedFromThirdParties");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterBankReconciliation");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractorOrdersIssued");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractComponents");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractorPlanning");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterOrdersByFulfillmentMethod");
	
	ProfileDescription.Roles.Add("ReadCatalogBillsOfMaterials");
	ProfileDescription.Roles.Add("ReadCatalogBillsOfMaterialsHierarchy");
	ProfileDescription.Roles.Add("ReadCatalogCompanies");
	ProfileDescription.Roles.Add("ReadCatalogCashAccounts");
	ProfileDescription.Roles.Add("ReadCatalogSalesOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogTransferOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogWorkOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogTags");
	ProfileDescription.Roles.Add("ReadCatalogPriceGroups");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartiesAccessGroups");
	ProfileDescription.Roles.Add("ReadCatalogDiscountTypes");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartyContractTypes");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartySegments");
	ProfileDescription.Roles.Add("ReadCatalogProjects");
	ProfileDescription.Roles.Add("ReadCatalogHSCodes");
	ProfileDescription.Roles.Add("ReadCatalogLegalForms");
	ProfileDescription.Roles.Add("ReadCatalogShippingAddresses");
	ProfileDescription.Roles.Add("ReadCatalogContractForms");
	ProfileDescription.Roles.Add("ReadCatalogActivityTypes");
	ProfileDescription.Roles.Add("ReadCatalogLegalDocuments");
	ProfileDescription.Roles.Add("ReadCatalogContactPersonsRoles");
	ProfileDescription.Roles.Add("ReadCatalogFixedAssets");
	ProfileDescription.Roles.Add("ReadCatalogPriceTypes");
	
	ProfileDescription.Roles.Add("ReadDocumentsJournalPurchaseDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsJournalSubcontractingDocumentsForServicesReceived");
	
	ProfileDescription.Roles.Add("ReadDocumentsSalesInvoice");
	ProfileDescription.Roles.Add("ReadDocumentsExpenseReport");
	ProfileDescription.Roles.Add("ReadDocumentsSalesOrder");
	ProfileDescription.Roles.Add("ReadDocumentsWorkOrder");
	ProfileDescription.Roles.Add("ReadDocumentsTransferOrder");
	ProfileDescription.Roles.Add("ReadDocumentsInventoryTransfer");
	ProfileDescription.Roles.Add("ReadDocumentsCreditNote");
	ProfileDescription.Roles.Add("ReadDocumentsPricing");
	ProfileDescription.Roles.Add("ReadDocumentsGoodsIssue");
	ProfileDescription.Roles.Add("ReadDocumentsCashVoucher");
	ProfileDescription.Roles.Add("ReadDocumentsCashReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsOnlinePayment");
	ProfileDescription.Roles.Add("ReadDocumentsOnlineReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsPaymentExpense");
	ProfileDescription.Roles.Add("ReadDocumentsPaymentReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsArApAdjustments");
	ProfileDescription.Roles.Add("ReadDocumentsFixedAssetSale");
	ProfileDescription.Roles.Add("ReadDocumentsAccountSalesFromConsignee");
	ProfileDescription.Roles.Add("ReadDocumentsSalesSlip");
	ProfileDescription.Roles.Add("ReadDocumentsShiftClosure");
	ProfileDescription.Roles.Add("ReadDocumentsTaxInvoiceIssued");
	ProfileDescription.Roles.Add("ReadDocumentsOpeningBalanceEntry");
	ProfileDescription.Roles.Add("ReadDocumentsKitOrder");
	
	ProfileDescription.Roles.Add("ReadInformationRegisterProductGLAccounts");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderFulfillmentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrdersPaymentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterPrices");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderPayments"); 
	ProfileDescription.Roles.Add("ReadInformationRegisterCounterpartyDuplicates");
	ProfileDescription.Roles.Add("ReadInformationRegisterInvoicesPaymentStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterUsingPaymentTermsInDocuments");
	ProfileDescription.Roles.Add("ReadInformationRegisterStandardTime");
	ProfileDescription.Roles.Add("ReadInformationRegisterSubstituteGoods");
	ProfileDescription.Roles.Add("ReadInformationRegisterPurchaseOrdersStates");
	ProfileDescription.Roles.Add("ReadInformationRegisterOverdraftLimits");
	
	ProfileDescription.Roles.Add("SubsystemPurchases");
	ProfileDescription.Roles.Add("SubsystemSettings");
	
	ProfileDescription.Roles.Add("UseDataProcessorDemandPlanning");
	ProfileDescription.Roles.Add("UseDataProcessorExportGoodsDatabaseToDCT");
	ProfileDescription.Roles.Add("UseDataProcessorOrdersClosing");
	ProfileDescription.Roles.Add("UseDataProcessorPrintGoodsReceivedNote");
	ProfileDescription.Roles.Add("UseDataProcessorProductsPurchase");
	ProfileDescription.Roles.Add("UseDataProcessorSubcontractorOrderIssuedProcessing");
	ProfileDescription.Roles.Add("UseDataProcessorSupplierPriceLists");
	ProfileDescription.Roles.Add("UseDataProcessorPrintLabelsAndTags");
	ProfileDescription.Roles.Add("UseDataProcessorCounterpartyDocuments");
	ProfileDescription.Roles.Add("UseDataProcessorSearchObjectsByBarcode");
	
	ProfileDescription.Roles.Add("UseReportAccountsPayable");
	ProfileDescription.Roles.Add("UseReportAccountsPayableAging");
	ProfileDescription.Roles.Add("UseReportCostOfSubcontractorGoods");
	ProfileDescription.Roles.Add("UseReportGoodsInvoicedNotReceived");
	ProfileDescription.Roles.Add("UseReportGoodsReceivedNotInvoiced");
	ProfileDescription.Roles.Add("UseReportInventoryFlowCalendar");
	ProfileDescription.Roles.Add("UseReportInvoicesValidForEPD");
	ProfileDescription.Roles.Add("UseReportPurchaseOrderAnalysis");
	ProfileDescription.Roles.Add("UseReportPurchaseOrderPayments");
	ProfileDescription.Roles.Add("UseReportPurchaseOrdersOverview");
	ProfileDescription.Roles.Add("UseReportPurchaseOrdersStatement");
	ProfileDescription.Roles.Add("UseReportPurchases");
	ProfileDescription.Roles.Add("UseReportStatementOfAccount");
	ProfileDescription.Roles.Add("UseReportSummaryOfGeneratedDocuments");
	ProfileDescription.Roles.Add("UseReportSupplierStatement");
	ProfileDescription.Roles.Add("UseReportSupplyPlanning");
	ProfileDescription.Roles.Add("UseReportCounterpartyContactInformation");
	ProfileDescription.Roles.Add("UseReportSubcontractorOrderIssuedStatement");
	ProfileDescription.Roles.Add("UseReportOrdersByFullfillment");
	ProfileDescription.Roles.Add("UseReportBankAccountsReport");
	
	ProfileDescription.Roles.Add("AddEditBusinessProcessPurchaseApproval");
	ProfileDescription.Roles.Add("AddEditPerformersRoles");
	
	// begin Drive.FullVersion
	
	// Production
	ProfileDescription.Roles.Add("AddEditProcessingSubsystem");
	ProfileDescription.Roles.Add("ReadCatalogProductionOrderStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsProductionOrder");
	ProfileDescription.Roles.Add("ReadDocumentsManufacturingOperation");
	ProfileDescription.Roles.Add("ReadDocumentsManufacturing");
	ProfileDescription.Roles.Add("ReadDocumentsProduction");
	ProfileDescription.Roles.Add("ReadCatalogSubcontractorOrderReceivedStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderReceived");
	ProfileDescription.Roles.Add("ReadCatalogManufacturingActivities");
	
	// end Drive.FullVersion
	
	AddAccountingRoles(ProfileDescription);
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("BusinessUnits", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CashAccounts", "AllAllowedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for the "Returns to vendors (additionally)" service profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "ReturnsToVendors";
	ProfileDescription.ID = "76337582-bff4-11df-9174-e0cb4ed5f4c3";
	ProfileDescription.Description = NStr("en = 'Returns to suppliers (additionally)'; ru = 'Возвраты поставщикам (дополнительно)';pl = 'Zwroty do dostawców (dodatkowo)';es_ES = 'Devoluciones a proveedores (adicionalmente)';es_CO = 'Devoluciones a proveedores (adicionalmente)';tr = 'Tedarikçilere iadeler (ek olarak)';it = 'Restituzioni ai fornitori (aggiuntivi)';de = 'Rückgaben an Lieferanten (zusätzlich)'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Service profile that allows you to work with returns to suppliers.'; ru = 'Служебный профиль, определяющий возможность работы с возвратами поставщикам.';pl = 'Profil serwisowy, który pozwala pracować ze zwrotami do dostawców.';es_ES = 'Perfil de servicio que le permite trabajar con devoluciones a proveedores.';es_CO = 'Perfil de servicio que le permite trabajar con devoluciones a proveedores.';tr = 'Tedarikçilere iade ile çalışmanızı sağlayan hizmet profili.';it = 'Profilo di servizio che ti permette di lavorare con rendimenti a fornitori.';de = 'Serviceprofil, mit dem Sie mit Rückgaben an Lieferanten arbeiten können.'");
	
	ProfileDescription.Roles.Add("AddEditReturnsToVendors");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

// begin Drive.FullVersion

#Region Production
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Production" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "Production";
	ProfileDescription.ID = "76337578-bff4-11df-9174-e0cb4ed5f4c3";
	ProfileDescription.Description = NStr("en = 'Production'; ru = 'Производство';pl = 'Produkcja';es_ES = 'Producción';es_CO = 'Producción';tr = 'Üretim';it = 'Produzione';de = 'Produktion'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to operate with the Production section.'; ru = 'Под профилем осуществляется работа с разделом ""Производство"".';pl = 'Użyj tego profilu do pracy z sekcją Produkcja.';es_ES = 'Utilizar este perfil para operar con la sección de Producción.';es_CO = 'Utilizar este perfil para operar con la sección de Producción.';tr = 'Üretim bölümü ile çalışmak için bu profili kullanın.';it = 'Utilizzare questo profilo per operare con la sezione di produzione.';de = 'Verwenden Sie dieses Profil, um mit dem Abschnitt Produktion zu arbeiten.'");
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("PrintFormsEdit");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	ProfileDescription.Roles.Add("DataSynchronizationSetting");
	ProfileDescription.Roles.Add("AddEditBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditReportsOptions");
	ProfileDescription.Roles.Add("AddEditIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddEditCatalogIndividuals");
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("EditAdditionalInfo");
	ProfileDescription.Roles.Add("EditPrintFormTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("ReadReportOptions");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("AddEditNotifications");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("ViewEventLog");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInfo");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangeLog");
	ProfileDescription.Roles.Add("ReadCurrencyRates");
	ProfileDescription.Roles.Add("AddEditPersonalMessagesTemplates");
	ProfileDescription.Roles.Add("AddEditInteractions");
	ProfileDescription.Roles.Add("AddEditInformationRegisterPrintFormsArchivingSettings");
	
	ProfileDescription.Roles.Add("SubsystemSettings");
	
	If Not CommonCached.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("StartThickClient");
	EndIf;
	
	// Basic rights
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("AddEditEventsAndTasks");
	ProfileDescription.Roles.Add("AddEditAdditionalAttributesAndInfo");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	ProfileDescription.Roles.Add("AddEditReportBulkEmails");
	ProfileDescription.Roles.Add("AddEditJobs");
	ProfileDescription.Roles.Add("ReadTasks");
	ProfileDescription.Roles.Add("UseReportManufacturingOverheadsStatement");
	
	// Subsystem
	ProfileDescription.Roles.Add("SubsystemProduction");
	
	// Catalogs
	ProfileDescription.Roles.Add("AddEditCatalogProducts");
	ProfileDescription.Roles.Add("AddEditCatalogProductsBatches");
	ProfileDescription.Roles.Add("AddEditCatalogProductsCategories");
	ProfileDescription.Roles.Add("AddEditCatalogProductsCharacteristics");
	ProfileDescription.Roles.Add("AddEditCatalogUOM");
	ProfileDescription.Roles.Add("AddEditCatalogUOMClassifier");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSales");
	ProfileDescription.Roles.Add("AddEditCatalogCostDrivers");
	ProfileDescription.Roles.Add("AddEditCatalogCostPools");
	ProfileDescription.Roles.Add("AddEditCalendarSchedules");
	ProfileDescription.Roles.Add("AddEditCatalogBusinessUnits");
	ProfileDescription.Roles.Add("UseDataImportFromExternalSources");
	
	ProfileDescription.Roles.Add("AddEditCatalogManufacturingActivities");
	ProfileDescription.Roles.Add("AddEditCatalogBillsOfMaterials");
	ProfileDescription.Roles.Add("AddEditCatalogBillsOfMaterialsHierarchy");
	ProfileDescription.Roles.Add("AddEditCatalogCompanyResources");
	ProfileDescription.Roles.Add("AddEditCatalogCompanyResourceTypes");
	ProfileDescription.Roles.Add("ReadCatalogSuppliersProducts");
	ProfileDescription.Roles.Add("ReadCatalogCells");
	ProfileDescription.Roles.Add("ReadInformationRegisterCounterpartyDuplicates");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsReceivable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterMiscellaneousPayable");
	ProfileDescription.Roles.Add("ReadCatalogHSCodes");
	ProfileDescription.Roles.Add("ReadCatalogPriceGroups");
	ProfileDescription.Roles.Add("ReadCatalogProjects");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryCostLayer");
	ProfileDescription.Roles.Add("ReadCatalogLegalForms");
	ProfileDescription.Roles.Add("ReadCatalogDiscountCards");
	ProfileDescription.Roles.Add("AddEditInformationRegisterBarcodes");
	ProfileDescription.Roles.Add("AddEditCatalogSerialNumbers");
	ProfileDescription.Roles.Add("ReadCatalogCompanies");
	ProfileDescription.Roles.Add("AddEditCatalogSerialNumbersTemplates");
	
	// Production order
	ProfileDescription.Roles.Add("AddEditDocumentsProductionOrder");
	ProfileDescription.Roles.Add("ReadDocumentsSalesOrder");
	ProfileDescription.Roles.Add("ReadCatalogSalesOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogBusinessUnits");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderReceived");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartyContracts");
	ProfileDescription.Roles.Add("ReadCatalogCounterparties");
	ProfileDescription.Roles.Add("ReadCatalogContactPersons");
	ProfileDescription.Roles.Add("AddEditCatalogProductionOrderStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsSalesInvoice");
	
	// Production
	ProfileDescription.Roles.Add("AddEditDocumentsProduction");
	
	// Inventory transfer
	ProfileDescription.Roles.Add("AddEditDocumentsInventoryTransfer");
	ProfileDescription.Roles.Add("AddEditDocumentsTransferOrder");
	ProfileDescription.Roles.Add("ReadDocumentsSupplierInvoice");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSerialNumbers");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryInWarehouses");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterTransferOrders");
	ProfileDescription.Roles.Add("ReadDocumentsWorkOrder");
	ProfileDescription.Roles.Add("ReadDocumentsGoodsReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsIntraWarehouseTransfer");
	ProfileDescription.Roles.Add("ReadCatalogSerialNumbers");
	ProfileDescription.Roles.Add("ReadDocumentsGoodsIssue");
	
	// Cost allocation
	ProfileDescription.Roles.Add("AddEditDocumentsCostAllocation");
	
	// Work-in-progress
	ProfileDescription.Roles.Add("AddEditDocumentsManufacturingOperation");
	ProfileDescription.Roles.Add("EditActualWorkloadInManufacturingOperation");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderIssued");
	
	// Manufacturing overhead rates
	ProfileDescription.Roles.Add("AddEditDocumentsManufacturingOverheadsRates");
	ProfileDescription.Roles.Add("ReadCatalogPriceTypes");
	
	// Kit processing
	ProfileDescription.Roles.Add("AddEditDocumentsKitOrder");
	ProfileDescription.Roles.Add("AddEditDocumentsKitProcessed");
	
	// Production tasks
	ProfileDescription.Roles.Add("AddEditDocumentsProductionTask");
	ProfileDescription.Roles.Add("ReadCatalogTeams");
	
	// Planning
	ProfileDescription.Roles.Add("UseFunctionalityProductionPlanning");
	ProfileDescription.Roles.Add("UseDataProcessorDemandPlanning");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterWorkOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPurchaseOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInvoicedNotReceived");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractorOrdersIssued");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryDemand");
	ProfileDescription.Roles.Add("ReadInformationRegisterReorderPointSettings");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryFlowCalendar");
	ProfileDescription.Roles.Add("ReadCatalogSupplierPriceTypes");
	
	// Reports
	ProfileDescription.Roles.Add("UseReportCostOfGoodsAssembled");
	ProfileDescription.Roles.Add("UseReportCostOfGoodsManufactured");
	ProfileDescription.Roles.Add("UseReportCostOfGoodsProduced");
	ProfileDescription.Roles.Add("UseReportWorkInProgress");
	ProfileDescription.Roles.Add("UseReportProductionStatusReport");
	ProfileDescription.Roles.Add("AddEditAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("UseReportProductRelease");
	ProfileDescription.Roles.Add("UseReportRawMaterialsCalculation");
	ProfileDescription.Roles.Add("UseReportDirectMaterialVariance");
	ProfileDescription.Roles.Add("UseReportProductionVarianceAnalysis");
	
	// Tools
	ProfileDescription.Roles.Add("UseDataProcessorOrdersClosing");
	ProfileDescription.Roles.Add("ReadDocumentsPurchaseOrder");
	ProfileDescription.Roles.Add("ReadCatalogPurchaseOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogWorkOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogSubcontractorOrderIssuedStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderIssued");
	ProfileDescription.Roles.Add("ReadCatalogSubcontractorOrderReceivedStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderReceived");
	
	AddAccountingRoles(ProfileDescription);
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("BusinessUnits", "AllAllowedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
		
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Production mobile interface" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "ProductionMobileInterface";
	ProfileDescription.ID = "55701856-7851-414e-b72c-55ad1909354f";
	ProfileDescription.Description = NStr("en = 'Production mobile interface'; ru = 'Мобильный интерфейс ""Производство""';pl = 'Interfejs mobilny Produkcja';es_ES = 'Interfaz móvil de producción';es_CO = 'Interfaz móvil de producción';tr = 'Üretim mobil arayüz';it = 'Interfaccia mobile Produzione';de = 'Produktive mobile Schnittstellen'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to manage Production tasks. For example, assign them and change their status.'; ru = 'Используйте этот профиль для управления производственными задачами. Например, чтобы назначать их или изменять их статус.';pl = 'Używaj tego profilu do zarządzania Zadaniami produkcyjnymi. Na przykład, do ich przydzielenia i zmiany ich statusów.';es_ES = 'Usar este perfil para gestionar las tareas de producción. Por ejemplo, asignarlas y cambiar su estado.';es_CO = 'Usar este perfil para gestionar las tareas de producción. Por ejemplo, asignarlas y cambiar su estado.';tr = 'Üretim görevlerini yönetmek için bu profili kullanın. Örneğin, görevleri atayın veya durumlarını değiştirin.';it = 'Utilizzare questo profilo per gestire gli Incarichi di produzione. Ad esempio, per assegnarli e modificare il loro stato.';de = 'Profil für die Verwaltung der Produktionsaufgaben verwenden. Zum Beispiel, um die Aufgaben anzunehmen und deren Status zu ändern.'");
	
	ProfileDescription.Roles.Add("AddEditDocumentsProductionTask");
	ProfileDescription.Roles.Add("UseDataProcessorPrintLabelsAndTags");
	ProfileDescription.Roles.Add("EditActualWorkloadInManufacturingOperation");
	ProfileDescription.Roles.Add("AddEditProductionOrdersPriorities");
	ProfileDescription.Roles.Add("UseFunctionalityProductionPlanning");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterProductionOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterWorkInProgressStatement");
	ProfileDescription.Roles.Add("ReadCatalogBillsOfMaterials");
	ProfileDescription.Roles.Add("ReadCatalogBillsOfMaterialsHierarchy");
	ProfileDescription.Roles.Add("ReadCatalogBusinessUnits");
	ProfileDescription.Roles.Add("ReadCatalogManufacturingActivities");
	ProfileDescription.Roles.Add("ReadCatalogProductsCategories");
	ProfileDescription.Roles.Add("ReadCatalogSuppliersProducts");
	ProfileDescription.Roles.Add("ReadCatalogProductsCharacteristics");
	ProfileDescription.Roles.Add("ReadCatalogProducts");
	ProfileDescription.Roles.Add("ReadCatalogTeams");
	ProfileDescription.Roles.Add("ReadCatalogUOMClassifier");
	ProfileDescription.Roles.Add("ReadCatalogUOM");
	ProfileDescription.Roles.Add("ReadCatalogCompanyResourceTypes");
	ProfileDescription.Roles.Add("ReadCatalogCompanyResources");
	ProfileDescription.Roles.Add("ReadCatalogCostPools");
	ProfileDescription.Roles.Add("ReadDocumentsManufacturingOperation");
	ProfileDescription.Roles.Add("ReadDocumentsProductionOrder");
	ProfileDescription.Roles.Add("ReadDocumentsManufacturing");
	ProfileDescription.Roles.Add("ReadInformationRegisterProductionOperationsSequence");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSales");
	ProfileDescription.Roles.Add("StartThickClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("UseProductionTasksInMobileClient");
	
	// For "UpdateDocumentStatuses" scheduled job
	ProfileDescription.Roles.Add("ReadDocumentsQuote");
	ProfileDescription.Roles.Add("ReadDocumentsSalesOrder");
	ProfileDescription.Roles.Add("ReadDocumentsSalesInvoice");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsReceivedNotInvoiced");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInvoicedNotReceived");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsShippedNotInvoiced");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInvoicedNotShipped");
	ProfileDescription.Roles.Add("ReadCatalogCompanies");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartyContracts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsReceivable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsPayable");
	ProfileDescription.Roles.Add("ReadInformationRegisterGoodsDocumentsStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterInvoicesPaymentStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsSupplierInvoice");
	ProfileDescription.Roles.Add("ReadInformationRegisterQuotationStatuses");
	
	AddAccountingRoles(ProfileDescription);
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("BusinessUnits", "AllAllowedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

// end Drive.FullVersion

#Region Funds
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Funds" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "Funds";
	ProfileDescription.ID = "76337575-bff4-11df-9174-e0cb4ed5f4c3";
	ProfileDescription.Description = NStr("en = 'Cash management'; ru = 'Финансы';pl = 'Środki pieniężne';es_ES = 'Gestión de efectivo';es_CO = 'Gestión de efectivo';tr = 'Finans';it = 'Tesoreria';de = 'Barmittelverwaltung'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to operate with the Cash management section: bank, cash, and cash flow projection.'; ru = 'Под профилем осуществляется работа с разделом Финансы: банк, касса и планирование ДДС.';pl = 'Użycie tego profilu do pracy z sekcją Środki pieniężne: bank, kasa i preliminarz płatności.';es_ES = 'Use este perfil para operar con la Sección de gestión de efectivo: banco, efectivo y proyección de flujo de efectivo.';es_CO = 'Use este perfil para operar con la Sección de gestión de efectivo: banco, efectivo y proyección de flujo de efectivo.';tr = 'Finans bölümü ile çalışmak için bu bölümü kullanın: banka, nakit ve ödeme takvimi.';it = 'Utilizza questo profilo per operare con la sezione gestione tesoreria: banca, cassa e proiezione del flusso di cassa.';de = 'Verwenden Sie dieses Profil, um mit dem Abschnitt Barmittelverwaltung zu arbeiten: Bank, Bargeld und Cashflow-Projektion.'");
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("PrintFormsEdit");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	ProfileDescription.Roles.Add("DataSynchronizationSetting");
	ProfileDescription.Roles.Add("AddEditBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditReportsOptions");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("EditAdditionalInfo");
	ProfileDescription.Roles.Add("EditPrintFormTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("ReadReportOptions");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("AddEditNotifications");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInfo");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangeLog");
	ProfileDescription.Roles.Add("ReadCurrencyRates");
	ProfileDescription.Roles.Add("AddEditPersonalMessagesTemplates");
	ProfileDescription.Roles.Add("AddEditInteractions");
	ProfileDescription.Roles.Add("AddEditInformationRegisterPrintFormsArchivingSettings");
	
	If Not CommonCached.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("StartThickClient");
	EndIf;
		
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("AddEditEventsAndTasks");
	ProfileDescription.Roles.Add("AddEditCounterparties");
	ProfileDescription.Roles.Add("ReadCashBalances");
	ProfileDescription.Roles.Add("ReadOrdersAndPaidBillsBalances");
	ProfileDescription.Roles.Add("ReadSettlementsBalances");
	ProfileDescription.Roles.Add("ReadSettlementsDocuments");
	ProfileDescription.Roles.Add("AddEditBankSubsystem");
	ProfileDescription.Roles.Add("AddEditPettyCashSubsystem");
	ProfileDescription.Roles.Add("AddEditFundsPlanningSubsystem");
	ProfileDescription.Roles.Add("SubsystemFinances");
	ProfileDescription.Roles.Add("AddEditCurrencies");
	ProfileDescription.Roles.Add("AddEditCatalogCashFlowItems");
	ProfileDescription.Roles.Add("UseFundsReports");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	ProfileDescription.Roles.Add("AddEditReportBulkEmails");
	ProfileDescription.Roles.Add("ReadReportBulkEmails");
	ProfileDescription.Roles.Add("AddEditJobs");
	ProfileDescription.Roles.Add("ReadTasks");
	ProfileDescription.Roles.Add("UseDataProcessorGenerateDirectDebits");
	ProfileDescription.Roles.Add("AddEditCatalogPaymentCardTypes");
	ProfileDescription.Roles.Add("AddEditCatalogPOSTerminals");
	ProfileDescription.Roles.Add("AddEditDocumentsOnlinePayment");
	ProfileDescription.Roles.Add("AddEditDocumentsOnlineReceipt");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterFundsTransfersBeingProcessed");
	ProfileDescription.Roles.Add("UseDataProcessorSearchObjectsByBarcode");
	ProfileDescription.Roles.Add("AddEditInformationRegisterOverdraftLimits");
	ProfileDescription.Roles.Add("ReadInformationRegisterOverdraftLimits");
	ProfileDescription.Roles.Add("UseReportBankAccountsReport");
	
	ProfileDescription.Roles.Add("AddEditDocumentsCashReceipt");
	ProfileDescription.Roles.Add("AddEditDocumentsCashVoucher");
	ProfileDescription.Roles.Add("AddEditDocumentsPaymentExpense");
	ProfileDescription.Roles.Add("AddEditDocumentsPaymentReceipt");
	
	ProfileDescription.Roles.Add("SubsystemSettings");
	
	// Work with files
	ProfileDescription.Roles.Add("FileOperations");
	ProfileDescription.Roles.Add("FileOperations");
	
	AddAccountingRoles(ProfileDescription);
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CashAccounts", "AllAllowedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

#Region Service
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Service" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name			= "Service";
	ProfileDescription.ID			= "76afd5ad-777a-11eb-978e-34cff651642b";	
	ProfileDescription.Description	= NStr("en = 'Service'; ru = 'Сервис';pl = 'Usługa';es_ES = 'Servicio';es_CO = 'Servicio';tr = 'Teknik servis';it = 'Servizio';de = 'Service'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details		= NStr("en = 'Use this profile to operate with the Service section.'; ru = 'Под профилем осуществляется работа с разделом Сервис.';pl = 'Używaj tego profilu do pracy z sekcją Usługa.';es_ES = 'Utilizar este perfil para operar con la sección de Servicio.';es_CO = 'Utilizar este perfil para operar con la sección de Servicio.';tr = 'Teknik servis bölümü ile çalışmak için bu profili kullan.';it = 'Utilizzare questo profilo per operare con la sezione Servizio.';de = 'Dieses Profil für Operationen mit dem Dienstleistungsabschnitt verwenden.'");
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("PrintFormsEdit");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	ProfileDescription.Roles.Add("DataSynchronizationSetting");
	ProfileDescription.Roles.Add("AddEditBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditReportsOptions");
	ProfileDescription.Roles.Add("AddEditIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddEditCatalogIndividuals");
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("EditAdditionalInfo");
	ProfileDescription.Roles.Add("EditPrintFormTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("ReadReportOptions");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("AddEditNotifications");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("ViewEventLog");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInfo");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangeLog");
	ProfileDescription.Roles.Add("ReadCurrencyRates");
	ProfileDescription.Roles.Add("AddEditPersonalMessagesTemplates");
	ProfileDescription.Roles.Add("AddEditInformationRegisterPrintFormsArchivingSettings");
	
	If Not CommonCached.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("StartThickClient");
	EndIf;
	
	ProfileDescription.Roles.Add("BasicRightsDrive");
	
	ProfileDescription.Roles.Add("AddEditAdditionalAttributesAndInfo");
	ProfileDescription.Roles.Add("UseDataImportFromExternalSources");
	ProfileDescription.Roles.Add("AddEditReportBulkEmails");
	ProfileDescription.Roles.Add("AddEditJobs");
	ProfileDescription.Roles.Add("ReadTasks");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	ProfileDescription.Roles.Add("EditDocumentPrices");
	
	ProfileDescription.Roles.Add("AddEditCatalogBillsOfMaterials");
	ProfileDescription.Roles.Add("AddEditCatalogBillsOfMaterialsHierarchy");
	ProfileDescription.Roles.Add("AddEditCatalogBundledServices");
	ProfileDescription.Roles.Add("AddEditCatalogCounterparties");
	ProfileDescription.Roles.Add("AddEditCatalogCounterpartyContracts");
	ProfileDescription.Roles.Add("AddEditCatalogDiscountCards");
	ProfileDescription.Roles.Add("AddEditCatalogEventsSubjects");
	ProfileDescription.Roles.Add("AddEditCatalogProducts");
	ProfileDescription.Roles.Add("AddEditCatalogProductsBatches");
	ProfileDescription.Roles.Add("AddEditCatalogProductsCharacteristics");
	ProfileDescription.Roles.Add("AddEditCatalogProjects");
	ProfileDescription.Roles.Add("AddEditCatalogRMAStatuses");
	ProfileDescription.Roles.Add("AddEditCatalogSerialNumbers");
	ProfileDescription.Roles.Add("AddEditCatalogTeams");
	ProfileDescription.Roles.Add("AddEditCatalogWorkSchedules");
	ProfileDescription.Roles.Add("AddEditCatalogUOMClassifier");
	ProfileDescription.Roles.Add("AddEditCatalogUOM");
	
	ProfileDescription.Roles.Add("AddEditDocumentsBulkMail");
	ProfileDescription.Roles.Add("AddEditDocumentsEvent");
	ProfileDescription.Roles.Add("AddEditDocumentsEmployeeTask");
	ProfileDescription.Roles.Add("AddEditDocumentsRMARequest");
	ProfileDescription.Roles.Add("AddEditDocumentsSalesOrder");
	ProfileDescription.Roles.Add("AddEditDocumentsWeeklyTimesheet");
	ProfileDescription.Roles.Add("AddEditDocumentsWorkOrder");
	
	ProfileDescription.Roles.Add("AddEditInformationRegisterBarcodes");
	ProfileDescription.Roles.Add("AddEditInformationRegisterCounterpartyDuplicates");
	ProfileDescription.Roles.Add("AddEditInformationRegisterVIESVATNumberValidation");
	ProfileDescription.Roles.Add("AddEditInformationRegisterWorkSchedules");
	ProfileDescription.Roles.Add("AddEditInformationRegisterProductGLAccounts");
	ProfileDescription.Roles.Add("AddEditInformationRegisterReorderPointSettings");
	ProfileDescription.Roles.Add("AddEditInformationRegisterStandardTime");
	ProfileDescription.Roles.Add("AddEditInformationRegisterSubstituteGoods");
	
	ProfileDescription.Roles.Add("UseReportAccountsReceivable");
	ProfileDescription.Roles.Add("UseReportAccountsReceivableAging");
	ProfileDescription.Roles.Add("UseReportAvailableStock");
	ProfileDescription.Roles.Add("UseReportBackorders");
	ProfileDescription.Roles.Add("UseReportEventCalendar");
	ProfileDescription.Roles.Add("UseReportGoodsInTransit");
	ProfileDescription.Roles.Add("UseReportInventoryFlowCalendar");
	ProfileDescription.Roles.Add("UseReportSalesOrderPayments");
	ProfileDescription.Roles.Add("UseReportSalesOrdersAnalysis");
	ProfileDescription.Roles.Add("UseReportSalesOrdersStatement");
	ProfileDescription.Roles.Add("UseReportSalesOrdersTrend");
	ProfileDescription.Roles.Add("UseReportStatementOfAccount");
	ProfileDescription.Roles.Add("UseReportWorkloadVariance");
	ProfileDescription.Roles.Add("UseReportWorkOrdersStatement");
	ProfileDescription.Roles.Add("UseDataProcessorDuplicateChecking");
	ProfileDescription.Roles.Add("UseDataProcessorEmployeeCalendar");
	ProfileDescription.Roles.Add("UseDataProcessorPrintRequisition");
	ProfileDescription.Roles.Add("UseDataProcessorPrintLabelsAndTags");
	ProfileDescription.Roles.Add("UseDataProcessorOrdersClosing");
	ProfileDescription.Roles.Add("ViewCommonFormAddressBook");
	ProfileDescription.Roles.Add("ViewCommonFormSelectDocumentInvoice");
	ProfileDescription.Roles.Add("UseDataProcessorSearchObjectsByBarcode");
	
	ProfileDescription.Roles.Add("ReadAccountingRegisterAccountingJournalEntriesCompound");
	ProfileDescription.Roles.Add("ReadChartsOfAccountsMasterChartOfAccounts");
	
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsReceivable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterBackorders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInTransit");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterEmployeeTasks");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventory");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryFlowCalendar");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryInWarehouses");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInvoicesAndOrdersPayment");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterMiscellaneousPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPaymentCalendar");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterReservedProducts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSales");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesWithCardBasedDiscounts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSerialNumbers");
	
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderPayments");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrdersPaymentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderFulfillmentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterQuotationStatuses"); 
	ProfileDescription.Roles.Add("ReadInformationRegisterCounterpartyDuplicates");
	ProfileDescription.Roles.Add("ReadInformationRegisterPrices");
	ProfileDescription.Roles.Add("ReadInformationRegisterStandardTime");
	ProfileDescription.Roles.Add("ReadInformationRegisterUsingPaymentTermsInDocuments");
	ProfileDescription.Roles.Add("ReadInformationRegisterWorkSchedules");
	ProfileDescription.Roles.Add("ReadInformationRegisterWorkSchedulesOfResources");
	
	ProfileDescription.Roles.Add("ReadCatalogActivityTypes");
	ProfileDescription.Roles.Add("ReadCatalogAutomaticDiscountTypes");
	ProfileDescription.Roles.Add("ReadCatalogBillsOfMaterials");
	ProfileDescription.Roles.Add("ReadCatalogBusinessUnits");
	ProfileDescription.Roles.Add("ReadCatalogCashAccounts");
	ProfileDescription.Roles.Add("ReadCatalogCells");
	ProfileDescription.Roles.Add("ReadCatalogCompanies");
	ProfileDescription.Roles.Add("ReadCatalogContactPersons");
	ProfileDescription.Roles.Add("ReadCatalogContactPersonsRoles");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartiesAccessGroups");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartyContracts");
	ProfileDescription.Roles.Add("ReadCatalogCustomerAcquisitionChannels");
	ProfileDescription.Roles.Add("ReadCatalogDirectDebitMandates");
	ProfileDescription.Roles.Add("ReadCatalogDiscountConditions");
	ProfileDescription.Roles.Add("ReadCatalogDiscountTypes");
	ProfileDescription.Roles.Add("ReadCatalogEarningAndDeductionTypes");
	ProfileDescription.Roles.Add("ReadCatalogEstimatesTemplates");
	ProfileDescription.Roles.Add("ReadCatalogHSCodes");
	ProfileDescription.Roles.Add("ReadCatalogIncoterms");
	ProfileDescription.Roles.Add("ReadCatalogJobAndEventStatuses");
	ProfileDescription.Roles.Add("ReadCatalogLeads");
	ProfileDescription.Roles.Add("ReadCatalogLegalForms");
	ProfileDescription.Roles.Add("ReadCatalogPaymentMethods");
	ProfileDescription.Roles.Add("ReadCatalogPaymentTermsTemplates");
	ProfileDescription.Roles.Add("ReadCatalogPriceGroups");
	ProfileDescription.Roles.Add("ReadCatalogPriceTypes");
	ProfileDescription.Roles.Add("ReadCatalogProductsBatches");
	ProfileDescription.Roles.Add("ReadCatalogProductsCategories");
	ProfileDescription.Roles.Add("ReadCatalogProductsCharacteristics");
	ProfileDescription.Roles.Add("ReadCatalogPurchaseOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogSalesOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogSalesTaxRates");
	ProfileDescription.Roles.Add("ReadCatalogSalesTerritories");
	ProfileDescription.Roles.Add("ReadCatalogSerialNumbers");
	ProfileDescription.Roles.Add("ReadCatalogShippingAddresses");
	ProfileDescription.Roles.Add("ReadCatalogSupplierPriceTypes");
	ProfileDescription.Roles.Add("ReadCatalogSuppliersProducts");
	ProfileDescription.Roles.Add("ReadCatalogTags");
	ProfileDescription.Roles.Add("ReadCatalogUOM");
	ProfileDescription.Roles.Add("ReadCatalogUOMClassifier");
	ProfileDescription.Roles.Add("ReadCatalogVATRates");
	ProfileDescription.Roles.Add("ReadCatalogWorkOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogJobAndEventStatuses");
	
	ProfileDescription.Roles.Add("ReadDocumentsGoodsIssue");
	ProfileDescription.Roles.Add("ReadDocumentsInventoryReservation");
	ProfileDescription.Roles.Add("ReadDocumentsPurchaseOrder");
	ProfileDescription.Roles.Add("ReadDocumentsPricing");
	ProfileDescription.Roles.Add("ReadDocumentsQuote");
	ProfileDescription.Roles.Add("ReadDocumentsSalesInvoice");
	ProfileDescription.Roles.Add("ReadDocumentsSalesSlip");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderIssued");
	ProfileDescription.Roles.Add("ReadDocumentsTransferOrder");
	ProfileDescription.Roles.Add("ReadDocumentsTaxInvoiceIssued");
	ProfileDescription.Roles.Add("ReadDocumentsJournalTimeTrackingDocuments");
	
	ProfileDescription.Roles.Add("SubsystemServices");
	ProfileDescription.Roles.Add("SubsystemSettings");
	
	AddAccountingRoles(ProfileDescription);
	
	// begin Drive.FullVersion
	
	// Production
	ProfileDescription.Roles.Add("ReadCatalogCostDrivers");
	ProfileDescription.Roles.Add("ReadCatalogManufacturingActivities");
	ProfileDescription.Roles.Add("ReadCatalogProductionOrderStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsProductionOrder");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderReceived");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterProductionOrders");
	
	// end Drive.FullVersion
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies",				"AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup",	"AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("BusinessUnits",			"AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CashAccounts",			"AllAllowedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

#Region CRM
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "CRM" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name			= "CRM";
	ProfileDescription.ID			= "47510738-7834-11eb-978e-34cff651642b";	
	ProfileDescription.Description	= NStr("en = 'CRM'; ru = 'CRM';pl = 'CRM';es_ES = 'CRM';es_CO = 'CRM';tr = 'CRM';it = 'CRM';de = 'CRM'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details		= NStr("en = 'Use this profile to operate with the CRM section.'; ru = 'Под профилем осуществляется работа с разделом CRM.';pl = 'Używaj tego profilu do pracy z sekcją CRM.';es_ES = 'Utilizar este perfil para operar con la sección de CRM.';es_CO = 'Utilizar este perfil para operar con la sección de CRM.';tr = 'SRM bölümü ile çalışmak için bu profili kullan.';it = 'Utilizzare questo profilo per operare con la sezione CRM.';de = 'Dieses Profil für Operationen mit CRM-Abschnitt verwenden.'");
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("PrintFormsEdit");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	ProfileDescription.Roles.Add("DataSynchronizationSetting");
	ProfileDescription.Roles.Add("AddEditBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditReportsOptions");
	ProfileDescription.Roles.Add("AddEditIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddEditCatalogIndividuals");
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("EditAdditionalInfo");
	ProfileDescription.Roles.Add("EditPrintFormTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("ReadReportOptions");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("AddEditNotifications");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("ViewEventLog");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInfo");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangeLog");
	ProfileDescription.Roles.Add("ReadCurrencyRates");
	ProfileDescription.Roles.Add("AddEditProducts");
	ProfileDescription.Roles.Add("AddEditPersonalMessagesTemplates");
	ProfileDescription.Roles.Add("AddEditInformationRegisterPrintFormsArchivingSettings");
	ProfileDescription.Roles.Add("UseDataProcessorSearchObjectsByBarcode");
	
	ProfileDescription.Roles.Add("SubsystemSettings");
	
	If Not CommonCached.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("StartThickClient");
	EndIf;
	
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("AddEditEventsAndTasks");
	ProfileDescription.Roles.Add("AddEditCounterparties");
	ProfileDescription.Roles.Add("AddEditInventoryMovements");
	ProfileDescription.Roles.Add("AddEditBankAccounts");
	ProfileDescription.Roles.Add("ReadDocumentsByBankAndPettyCash");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	ProfileDescription.Roles.Add("AddEditReportBulkEmails");
	ProfileDescription.Roles.Add("ReadReportBulkEmails");
	ProfileDescription.Roles.Add("AddEditJobs");
	ProfileDescription.Roles.Add("ReadTasks");
	ProfileDescription.Roles.Add("EditDocumentPrices");
	ProfileDescription.Roles.Add("SubsystemCRM");
	
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsReceivable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterMiscellaneousPayable");
	
	AddAccountingRoles(ProfileDescription);
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies",				"AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup",	"AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CashAccounts",			"AllAllowedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

#Region Salary
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Salary" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name           = "Salary";
	ProfileDescription.ID = "76337574-bff4-11df-9174-e0cb4ed5f4c3";
	ProfileDescription.Description = NStr("en = 'Payroll'; ru = 'Зарплата';pl = 'Lista płac';es_ES = 'Nómina';es_CO = 'Nómina';tr = 'Bordro';it = 'Stipendi';de = 'Personal'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to operate with the Payroll section: HR recordkeeping and payroll.'; ru = 'Под профилем осуществляется работа с разделом ""Зарплата"": кадровый учет и расчет зарплаты.';pl = 'Użyj tego profilu, aby pracować z Sekcją płac: zarządzanie zasobami ludzkimi i lista płac.';es_ES = 'Utilizar este perfil para operar con la sección de Nómina: conservación de registros de los recursos humanos y nómina.';es_CO = 'Utilizar este perfil para operar con la sección de Nómina: conservación de registros de los recursos humanos y nómina.';tr = 'Bordro bölümü ile çalışmak için bu profili kullanın: İK kayıtları ve bordrolar.';it = 'Utilizzare questo profilo per operare con la sezione Payroll: registri HR e del libro paga.';de = 'Verwenden Sie dieses Profil, um mit dem Abschnitt ""Gehaltsabrechnung"" zu arbeiten: Personalaktenverwaltung und Gehaltsabrechnung.'");
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("PrintFormsEdit");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	ProfileDescription.Roles.Add("AddEditBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditCommonBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditReportsOptions");
	ProfileDescription.Roles.Add("AddEditIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("AddEditCatalogIndividuals");
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("EditAdditionalInfo");
	ProfileDescription.Roles.Add("EditPrintFormTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("ReadReportOptions");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("AddEditNotifications");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInfo");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangeLog");
	ProfileDescription.Roles.Add("AddEditPersonalMessagesTemplates");
	ProfileDescription.Roles.Add("AddEditInteractions");
	ProfileDescription.Roles.Add("AddEditInformationRegisterPrintFormsArchivingSettings");
	ProfileDescription.Roles.Add("UseDataProcessorSearchObjectsByBarcode");
	
	If Not CommonCached.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("StartThickClient");
	EndIf;
	
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("AddEditEventsAndTasks");
	ProfileDescription.Roles.Add("AddEditHumanResourcesSubsystem");
	ProfileDescription.Roles.Add("AddEditPayrollSubsystem");
	ProfileDescription.Roles.Add("ReadEarningsAndTimesheetBalances");
	ProfileDescription.Roles.Add("UsePayrollReports");
	ProfileDescription.Roles.Add("AddEditReportBulkEmails");
	ProfileDescription.Roles.Add("ReadReportBulkEmails");
	ProfileDescription.Roles.Add("AddEditJobs");
	ProfileDescription.Roles.Add("ReadTasks");
	
	ProfileDescription.Roles.Add("SubsystemSettings");
	
	AddAccountingRoles(ProfileDescription);
	
	// Work with files
	ProfileDescription.Roles.Add("FileOperations");
	ProfileDescription.Roles.Add("FileOperations");
	
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

#Region Accounting
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Accounting" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name = "Accounting";
	ProfileDescription.ID = "88f13002-16d0-4a32-b092-93f15299eb76";
	ProfileDescription.Description = NStr("en = 'Accounting and finance'; ru = 'Бухгалтерия и финансы';pl = 'Księgowość i finanse';es_ES = 'Contabilidad y fianzas';es_CO = 'Contabilidad y fianzas';tr = 'Muhasebe ve Finans';it = 'Contabilità e finanza';de = 'Buchhaltung und Finanzen'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to operate with the Company and Analysis sections.'; ru = 'Данный профиль используется для работы с разделами Организация и Анализ';pl = 'Użyj tego profilu do pracy z sekcjami Firma i Analiza.';es_ES = 'Utilizar este perfil para operar con las secciones de Empresas y Análisis.';es_CO = 'Utilizar este perfil para operar con las secciones de Empresas y Análisis.';tr = 'İş yeri ve Analiz bölümleriyle çalışmak için bu profili kullanın.';it = 'Utilizzare questo profilo per operare con le sezioni Azienda e Analisi.';de = 'Verwenden Sie dieses Profil, um mit den Bereichen Firma und Analyse zu arbeiten.'");
	
	AddReadRoles(ProfileDescription);
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("PrintFormsEdit");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	ProfileDescription.Roles.Add("DataSynchronizationSetting");
	ProfileDescription.Roles.Add("AddEditBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditReportsOptions");
	ProfileDescription.Roles.Add("AddEditIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("EditAdditionalInfo");
	ProfileDescription.Roles.Add("EditPrintFormTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("ReadReportOptions");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("AddEditNotifications");
	ProfileDescription.Roles.Add("SubsystemAccounting");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("ViewEventLog");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInfo");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangeLog");
	ProfileDescription.Roles.Add("ReadCurrencyRates");
	ProfileDescription.Roles.Add("AddEditPersonalMessagesTemplates");
	ProfileDescription.Roles.Add("AddEditInteractions");
	ProfileDescription.Roles.Add("AddEditInformationRegisterPrintFormsArchivingSettings");
	ProfileDescription.Roles.Add("UseDataProcessorSearchObjectsByBarcode");
	ProfileDescription.Roles.Add("AddEditInformationRegisterAccountingPolicy");
	ProfileDescription.Roles.Add("AddEditInformationRegisterCompaniesTypesOfAccounting");
	
	If Not CommonCached.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("StartThickClient");
	EndIf;
	
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("AddEditEventsAndTasks");
	ProfileDescription.Roles.Add("AddEditCounterparties");
	ProfileDescription.Roles.Add("ReadCashBalances");
	ProfileDescription.Roles.Add("ReadOrdersAndPaidBillsBalances");
	ProfileDescription.Roles.Add("ReadSettlementsBalances");
	ProfileDescription.Roles.Add("ReadSettlementsDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsMovementsOnInventory");
	ProfileDescription.Roles.Add("ReadInventoryAndSettlementsBalances");
	ProfileDescription.Roles.Add("AddEditBankSubsystem");
	ProfileDescription.Roles.Add("AddEditPettyCashSubsystem");
	ProfileDescription.Roles.Add("AddEditLoanManagementSubsystem");
	ProfileDescription.Roles.Add("AddEditFundsPlanningSubsystem");
	ProfileDescription.Roles.Add("AddEditTaxReportsSubsystem");
	ProfileDescription.Roles.Add("AddEditCurrencies");
	ProfileDescription.Roles.Add("AddEditCatalogCashFlowItems");
	ProfileDescription.Roles.Add("UsePeripherals");
	ProfileDescription.Roles.Add("DataExchangeWithMobileApplication");
	ProfileDescription.Roles.Add("AddEditReportBulkEmails");
	ProfileDescription.Roles.Add("ReadReportBulkEmails");
	ProfileDescription.Roles.Add("AddEditJobs");
	ProfileDescription.Roles.Add("ReadTasks");
	
	// Work with files
	ProfileDescription.Roles.Add("FileOperations");
	ProfileDescription.Roles.Add("FileOperations");
	
	// Accounting and Finance
	ProfileDescription.Roles.Add("UseAnalysisReports");
	ProfileDescription.Roles.Add("UseEnterpriseReports");
	ProfileDescription.Roles.Add("UseProductionReports");
	ProfileDescription.Roles.Add("UseSalesReports");
	ProfileDescription.Roles.Add("UsePurchasesReports");
	ProfileDescription.Roles.Add("UseFundsReports");
	ProfileDescription.Roles.Add("AddEditFinancialInformation");
	ProfileDescription.Roles.Add("EditDocumentPrices");
	ProfileDescription.Roles.Add("SubsystemFinancialAccounting");
	ProfileDescription.Roles.Add("ChangeApprovedDocuments");
	ProfileDescription.Roles.Add("EditAccountingEntries");
	ProfileDescription.Roles.Add("AddEditCatalogTaxTypes");
	ProfileDescription.Roles.Add("AddEditDocumentsDirectDebit");
	
	ProfileDescription.Roles.Add("SubsystemSettings");
	
	// Income and expenses items
	ProfileDescription.Roles.Add("AddEditCatalogDefaultIncomeAndExpenseItems");
	ProfileDescription.Roles.Add("AddEditCatalogIncomeAndExpenseItems");
	ProfileDescription.Roles.Add("AddEditCatalogIncomeAndExpenseTypes");
	ProfileDescription.Roles.Add("AddEditInformationRegisterCounterpartyIncomeAndExpenseItems");
	ProfileDescription.Roles.Add("AddEditInformationRegisterProductIncomeAndExpenseItems");
	ProfileDescription.Roles.Add("UseDataProcessorMappingGLAccountsToIncomeAndExpenseItems");
	
	// Project management
	ProfileDescription.Roles.Add("AddEditCatalogProjects");
	ProfileDescription.Roles.Add("AddEditCatalogProjectPhases");
	ProfileDescription.Roles.Add("AddEditCatalogProjectTemplates");
	ProfileDescription.Roles.Add("AddEditInformationRegisterProjectPhasesOrder");
	ProfileDescription.Roles.Add("AddEditInformationRegisterProjectPhasesTimelines");
	ProfileDescription.Roles.Add("AddEditInformationRegisterWorkSchedulePeriodSettings");
	ProfileDescription.Roles.Add("AddEditBusinessProcessProjectJob");
	ProfileDescription.Roles.Add("UseReportProjectPhases");
	ProfileDescription.Roles.Add("UseReportProjectPhasesProgress");
	ProfileDescription.Roles.Add("UseReportProjectPhasesStatusChanges");
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup", "AllAllowedByDefault");
	
	// Duplicates blocking
	ProfileDescription.Roles.Add("AddEditCatalogDuplicateRules");
	
	// Taxes
	ProfileDescription.Roles.Add("AddEditTaxesSubsystem");
	
	// Accounting templates
	ProfileDescription.Roles.Add("ReadCatalogAccountingEntriesCategories");
	ProfileDescription.Roles.Add("ReadCatalogAccountingEntriesTemplates");
	ProfileDescription.Roles.Add("ReadCatalogAccountingTransactionsTemplates");
	ProfileDescription.Roles.Add("ReadCatalogChartsOfAccounts");
	ProfileDescription.Roles.Add("ReadCatalogTypesOfAccounting");
	ProfileDescription.Roles.Add("ReadCatalogDefaultAccounts");
	ProfileDescription.Roles.Add("ReadCatalogDefaultAccountsTypes");
	ProfileDescription.Roles.Add("ReadCatalogAnalyticalDimensionsSets");
	
	ProfileDescription.Roles.Add("ReadChartsOfAccountsMasterChartOfAccounts");
	
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingPolicy");
	ProfileDescription.Roles.Add("ReadInformationRegisterMasterChartOfAccountsHistory");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingEntriesTemplatesStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterCompaniesTypesOfAccounting");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingSourceDocuments");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingTransactionDocuments");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingTransactionGenerationSettings");
	
	ProfileDescription.Roles.Add("AddEditDocumentsAccountingTransaction");
	
	ProfileDescription.Roles.Add("ReadChartOfCharacteristicTypesManagerialAnalyticalDimensionTypes");
	
	ProfileDescription.Roles.Add("AddEditAccountingRegisterAccountingJournalEntriesCompound");
	ProfileDescription.Roles.Add("AddEditAccountingRegisterAccountingJournalEntriesSimple");
	
	ProfileDescription.Roles.Add("ViewCommonFormArbitraryParametersChoiceForm");
	
	ProfileDescription.Roles.Add("EditAccountingEntries");
	ProfileDescription.Roles.Add("UseAccountingEntriesManagement");
	
	ProfileDescription.Roles.Add("UseReportTrialBalanceMaster");
	ProfileDescription.Roles.Add("UseReportAccountEntries");
	ProfileDescription.Roles.Add("UseReportAccountAnalysis");
	ProfileDescription.Roles.Add("UseReportEntriesReport");

	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

#Region DocumentsReposting
	
	// Description for "Documents reposting" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name = "DocumentsReposting";
	ProfileDescription.ID = "61829616-cbe7-41ec-bd1e-d8f7ecbc78b2";
	ProfileDescription.Description = NStr("en = 'Documents reposting'; ru = 'Перепроведение документов';pl = 'Przeksięgowanie dokumentów';es_ES = 'Rellenar documento';es_CO = 'Rellenar documento';tr = 'Belgeleri yeniden yayınlama';it = 'Ripubblicazione documenti';de = 'Umbuchung von Belegen'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Service profile that allows you to repost documents.'; ru = 'Служебный профиль, позволяющий вам перепроводить документы.';pl = 'Profile usługi, który pozwala ci przeksięgowanie dokumentów.';es_ES = 'Perfil de servicio que permite reenviar los documentos.';es_CO = 'Perfil de servicio que permite reenviar los documentos.';tr = 'Belgeleri yeniden yayınlamanıza izin veren hizmet profili.';it = 'Profilo di servizio che consente di ripubblicare documenti.';de = 'Serviceprofil, mit dem Sie Belege umbuchen können.'");
	
	ProfileDescription.Roles.Add("DocumentsReposting");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

#Region Warehouse
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Warehouse" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name = "Warehouse";
	ProfileDescription.ID = "f3d56569-bc1d-4a0d-b499-f4f6cd9414c9";
	ProfileDescription.Description = NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to operate with the Warehouse section.'; ru = 'Под профилем осуществляется работа с разделом Склад.';pl = 'Użyj tego profilu do pracy z sekcją Magazyn.';es_ES = 'Utilizar este perfil para operar con la sección de Almacén.';es_CO = 'Utilizar este perfil para operar con la sección de Almacén.';tr = 'Ambar bölümü ile çalışmak için bu profili kullanın.';it = 'Utilizzare questo profilo per operare con la sezione Magazzino.';de = 'Verwenden Sie dieses Profil für Operationen mit dem Lagerabschnitt.'");
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	ProfileDescription.Roles.Add("PrintFormsEdit");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	ProfileDescription.Roles.Add("DataSynchronizationSetting");
	ProfileDescription.Roles.Add("AddEditBasicReferenceData");
	ProfileDescription.Roles.Add("AddEditReportsOptions");
	ProfileDescription.Roles.Add("AddEditIndividualsPersonalData");
	ProfileDescription.Roles.Add("AddEditCountries");
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");
	ProfileDescription.Roles.Add("EditAdditionalInfo");
	ProfileDescription.Roles.Add("EditPrintFormTemplates");
	ProfileDescription.Roles.Add("EditCurrentUser");
	ProfileDescription.Roles.Add("ReadReportOptions");
	ProfileDescription.Roles.Add("UseGlobalAdditionalReportsAndDataProcessors");
	ProfileDescription.Roles.Add("AddEditNotifications");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseEMailAccounts");
	ProfileDescription.Roles.Add("ViewEventLog");
	ProfileDescription.Roles.Add("EditObjectAttributes");
	ProfileDescription.Roles.Add("ReadBasicReferenceData");
	ProfileDescription.Roles.Add("ReadAdditionalInfo");
	ProfileDescription.Roles.Add("ReadIndividualsPersonalData");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ViewApplicationChangeLog");
	ProfileDescription.Roles.Add("ReadCurrencyRates");
	ProfileDescription.Roles.Add("AddEditPersonalMessagesTemplates");
	ProfileDescription.Roles.Add("AddEditInteractions");
	ProfileDescription.Roles.Add("AddEditInformationRegisterPrintFormsArchivingSettings");
	
	If Not CommonCached.DataSeparationEnabled() Then
		ProfileDescription.Roles.Add("StartThickClient");
	EndIf;
	
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("AddEditReportBulkEmails");
	ProfileDescription.Roles.Add("ReadReportBulkEmails");
	ProfileDescription.Roles.Add("AddEditJobs");
	ProfileDescription.Roles.Add("ReadTasks");
	ProfileDescription.Roles.Add("UsePeripherals");
	
	ProfileDescription.Roles.Add("SubsystemWarehouse");
	ProfileDescription.Roles.Add("SubsystemSettings");
	
	ProfileDescription.Roles.Add("AddEditDocumentsInventoryTransfer");
	ProfileDescription.Roles.Add("AddEditDocumentsInventoryReservation");
	ProfileDescription.Roles.Add("AddEditDocumentsGoodsIssue");
	ProfileDescription.Roles.Add("AddEditDocumentsGoodsReceipt");
	ProfileDescription.Roles.Add("AddEditDocumentsStocktaking");
	ProfileDescription.Roles.Add("AddEditDocumentsInventoryIncrease");
	ProfileDescription.Roles.Add("AddEditDocumentsInventoryWriteOff");
	ProfileDescription.Roles.Add("AddEditDocumentsTransferOrder");
	ProfileDescription.Roles.Add("AddEditDocumentsPackingSlip");
	ProfileDescription.Roles.Add("AddEditDocumentsIntraWarehouseTransfer");
	
	ProfileDescription.Roles.Add("AddEditCatalogBusinessUnits");
	ProfileDescription.Roles.Add("AddEditCatalogProducts");
	ProfileDescription.Roles.Add("AddEditCatalogProductsBatches");
	ProfileDescription.Roles.Add("AddEditCatalogProductsCategories");
	ProfileDescription.Roles.Add("AddEditCatalogProductsCharacteristics");
	ProfileDescription.Roles.Add("AddEditCatalogSerialNumbers");
	ProfileDescription.Roles.Add("AddEditCatalogSerialNumbersTemplates");
	ProfileDescription.Roles.Add("AddEditCatalogCells");
	ProfileDescription.Roles.Add("AddEditCatalogContainerTypes");
	ProfileDescription.Roles.Add("AddEditCatalogBatchSettings");
	ProfileDescription.Roles.Add("AddEditCatalogBatchTrackingPolicies");
	ProfileDescription.Roles.Add("AddEditCatalogTransferOrderStatuses");
	ProfileDescription.Roles.Add("AddEditCatalogBillsOfMaterialsHierarchy");
	
	ProfileDescription.Roles.Add("AddEditInformationRegisterStandardTime");
	ProfileDescription.Roles.Add("AddEditInformationRegisterReorderPointSettings");
	ProfileDescription.Roles.Add("AddEditInformationRegisterBarcodes");
	ProfileDescription.Roles.Add("AddEditInformationRegisterBatchTrackingPolicy");
	ProfileDescription.Roles.Add("ReadInformationRegisterPrices");
	ProfileDescription.Roles.Add("ReadInformationRegisterSubstituteGoods");
	ProfileDescription.Roles.Add("ReadInformationRegisterCounterpartyDuplicates");
	ProfileDescription.Roles.Add("ReadInformationRegisterVIESVATNumberValidation");
	
	ProfileDescription.Roles.Add("ReadDocumentsSalesOrder");
	ProfileDescription.Roles.Add("ReadDocumentsPurchaseOrder");
	ProfileDescription.Roles.Add("ReadDocumentsSupplierInvoice");
	ProfileDescription.Roles.Add("ReadDocumentsSalesInvoice");
	ProfileDescription.Roles.Add("ReadDocumentsWorkOrder");
	ProfileDescription.Roles.Add("ReadDocumentsEvent");
	ProfileDescription.Roles.Add("ReadDocumentsActualSalesVolume");
	ProfileDescription.Roles.Add("ReadDocumentsAdditionalExpenses");
	ProfileDescription.Roles.Add("ReadDocumentsOpeningBalanceEntry");
	ProfileDescription.Roles.Add("ReadDocumentsAccountSalesFromConsignee");
	ProfileDescription.Roles.Add("ReadDocumentsCreditNote");
	ProfileDescription.Roles.Add("ReadDocumentsShiftClosure");
	ProfileDescription.Roles.Add("ReadDocumentsFixedAssetRecognition");
	ProfileDescription.Roles.Add("ReadDocumentsCustomsDeclaration");
	ProfileDescription.Roles.Add("ReadDocumentsAccountSalesToConsignor");
	ProfileDescription.Roles.Add("ReadDocumentsSalesSlip");
	ProfileDescription.Roles.Add("ReadDocumentsTaxInvoiceIssued");
	ProfileDescription.Roles.Add("ReadDocumentsTaxInvoiceReceived");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderIssued");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorInvoiceReceived");
	
	ProfileDescription.Roles.Add("ReadCatalogBillsOfMaterials");
	ProfileDescription.Roles.Add("ReadCatalogCounterparties");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartyContracts");
	ProfileDescription.Roles.Add("ReadCatalogDiscountTypes");
	ProfileDescription.Roles.Add("ReadCatalogUOM");
	ProfileDescription.Roles.Add("ReadCatalogUOMClassifier");
	ProfileDescription.Roles.Add("ReadCatalogCompanies");
	ProfileDescription.Roles.Add("ReadCatalogSupplierPriceTypes");
	ProfileDescription.Roles.Add("ReadCatalogPriceTypes");
	ProfileDescription.Roles.Add("ReadCatalogPurchaseOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogSalesOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogWorkOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogSubcontractorOrderIssuedStatuses");
	ProfileDescription.Roles.Add("ReadCatalogContactPersons");
	ProfileDescription.Roles.Add("ReadCatalogShippingAddresses");
	ProfileDescription.Roles.Add("ReadCatalogHSCodes");
	ProfileDescription.Roles.Add("ReadCatalogSuppliersProducts");
	
	ProfileDescription.Roles.Add("ReadAccountingRegisterAccountingJournalEntriesCompound");
	ProfileDescription.Roles.Add("ReadChartsOfAccountsMasterChartOfAccounts");
	
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSales");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterMiscellaneousPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsReceivable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInvoicedNotReceived");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsReceivedNotInvoiced");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsShippedNotInvoiced");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInvoicedNotShipped");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterStockReceivedFromThirdParties");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterStockTransferredToThirdParties");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSerialNumbers");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterTransferOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterBackorders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPackedOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPurchaseOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryInWarehouses");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventory");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryCostLayer");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryFlowCalendar");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterLandedCosts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterReservedProducts");
	
	ProfileDescription.Roles.Add("UseReportAvailableStock");
	ProfileDescription.Roles.Add("UseReportInventoryFlowCalendar");
	ProfileDescription.Roles.Add("UseReportSurplusesAndShortages");
	ProfileDescription.Roles.Add("UseReportStockStatement");
	ProfileDescription.Roles.Add("UseReportStockStatementWithCostLayers");
	ProfileDescription.Roles.Add("UseReportBackorders");
	ProfileDescription.Roles.Add("UseReportStockSummary");
	ProfileDescription.Roles.Add("UseReportGoodsInvoicedNotReceived");
	ProfileDescription.Roles.Add("UseReportGoodsReceivedNotInvoiced");
	ProfileDescription.Roles.Add("UseReportGoodsShippedNotInvoiced");
	ProfileDescription.Roles.Add("UseReportGoodsInvoicedNotShipped");
	ProfileDescription.Roles.Add("UseReportPackingSlips");
	ProfileDescription.Roles.Add("UseReportStockReceivedFromThirdParties");
	ProfileDescription.Roles.Add("UseReportStockTransferredToThirdParties");
	ProfileDescription.Roles.Add("UseReportTransferOrderAnalysis");
	ProfileDescription.Roles.Add("UseReportTransferOrdersAnalysis");
	ProfileDescription.Roles.Add("UseReportTransferOrdersStatement");
	
	ProfileDescription.Roles.Add("ReadDocumentsJournalStocktakingDocuments");
	
	ProfileDescription.Roles.Add("UseDataProcessorPrintLabelsAndTags");
	ProfileDescription.Roles.Add("UseDataProcessorSearchObjectsByBarcode");
	
	// begin Drive.FullVersion
	
	// Production
	ProfileDescription.Roles.Add("ReadCatalogProductionOrderStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsProductionOrder");
	ProfileDescription.Roles.Add("ReadDocumentsManufacturingOperation");
	ProfileDescription.Roles.Add("ReadDocumentsManufacturing");
	ProfileDescription.Roles.Add("ReadDocumentsProduction");
	
	// end Drive.FullVersion
	
	// Kit processing
	
	ProfileDescription.Roles.Add("UseReportCostOfGoodsAssembled");
	ProfileDescription.Roles.Add("AddEditDocumentsKitOrder");
	ProfileDescription.Roles.Add("AddEditDocumentsKitProcessed");
	
	// End kit processing
	
	AddAccountingRoles(ProfileDescription);
	
	//Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("CounterpartiesGroup", "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("BusinessUnits", "AllAllowedByDefault");
	
	// Duplicates blocking
	ProfileDescription.Roles.Add("AddEditCatalogDuplicateRules");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

#Region ExternalUser
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "External user" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name			= "ExternalUser";
	ProfileDescription.ID			= "1f64f91c-335d-429b-b44d-85849a72db65";
	ProfileDescription.Description	= NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Purpose		= CommonClientServer.ValueInArray(Metadata.DefinedTypes.ExternalUser.Type);
	ProfileDescription.Details		= NStr("en = 'Use this profile to give external customers access to Sales documents, catalogs, and reports.'; ru = 'Используйте этот профиль, чтобы предоставить внешним покупателям доступ к документам продаж, справочникам и отчетам.';pl = 'Używaj tego profilu aby udzielić dostępu do dokumentów Sprzedaży, katalogów i raportów.';es_ES = 'Utilice este perfil para dar a los clientes externos acceso a los documentos de ventas, catálogos e informes.';es_CO = 'Utilice este perfil para dar a los clientes externos acceso a los documentos de ventas, catálogos e informes.';tr = 'Harici müşterilere Satış belgelerine, kataloglara ve raporlara erişim vermek için bu profili kullanın.';it = 'Utilizzare questo profilo per dare ai clienti esterni accesso ai documenti di vendita, cataloghi e report.';de = 'Verwenden Sie dieses Profil, um Zugriff auf Verkaufsdokumenten, Katalogen und Berichten für externe Kunden zu geben.'");
	
	// Common
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("OutputToPrinterFileClipboard");
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRightsForExternalUsers");
	
	// Drive
	ProfileDescription.Roles.Add("BasicRightsDriveForExternalUsers");
	ProfileDescription.Roles.Add("EditCatalogCounterpartiesForExternalUsers");
	ProfileDescription.Roles.Add("EditCatalogContactPersonsForExternalUsers");
	ProfileDescription.Roles.Add("EditCatalogBankAccountsForExternalUsers");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsPayableForExternalUsers");
	ProfileDescription.Roles.Add("UseReportCounterpartyContactInformationForExternalUsers");
	ProfileDescription.Roles.Add("UseReportCustomerStatementForExternalUsers");
	ProfileDescription.Roles.Add("UseReportStatementOfAccountForExternalUsers");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsReceivableForExternalUsers");
	ProfileDescription.Roles.Add("EditCatalogCounterpartyContractsForExternalUsers");
	ProfileDescription.Roles.Add("ReadDocumentsReconciliationStatementForExternalUsers");
	ProfileDescription.Roles.Add("ReadCatalogFilesForExternalUsers");
	ProfileDescription.Roles.Add("AddEditBusinessProcessJobForExternalUsers");
	ProfileDescription.Roles.Add("ReadCatalogCompaniesForExternalUsers");
	ProfileDescription.Roles.Add("PrintFormsEditForExternalUsers");
	ProfileDescription.Roles.Add("ReadDocumentsQuoteForExternalUsers");
	ProfileDescription.Roles.Add("ReadDocumentsGoodsIssueForExternalUsers");
	ProfileDescription.Roles.Add("AddDocumentsSalesOrderForExternalUsers");
	ProfileDescription.Roles.Add("ReadCatalogQuotationStatuses");
	ProfileDescription.Roles.Add("ReadCatalogProducts");
	ProfileDescription.Roles.Add("ReadCatalogProductsCharacteristics");
	ProfileDescription.Roles.Add("ReadCatalogProductsBatches");
	ProfileDescription.Roles.Add("ReadCatalogUOM");
	ProfileDescription.Roles.Add("ReadCatalogBusinessUnits");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesOrdersForExternalUsers");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesForExternalUsers");
	ProfileDescription.Roles.Add("ReadCatalogSalesOrderStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderFulfillmentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrdersPaymentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderPayments");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesForExternalUsers");
	ProfileDescription.Roles.Add("ReadDocumentsSalesInvoiceForExternalUsers");
	ProfileDescription.Roles.Add("ReadInformationRegisterInvoicesPaymentStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsTaxInvoiceIssuedForExternalUsers");
	ProfileDescription.Roles.Add("ReadDocumentsCreditNoteForExternalUsers");
	ProfileDescription.Roles.Add("UseDataProcessorProductCartForExternalUsers");
	ProfileDescription.Roles.Add("ReadCatalogDiscountTypes");
	ProfileDescription.Roles.Add("ReadCatalogDiscountCardsForExternalUsers");
	ProfileDescription.Roles.Add("ReadCatalogProductAccessGroupsForExternalUsers");
	ProfileDescription.Roles.Add("ReadInformationRegisterPrices");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryInWarehouses");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterReservedProductsForExternalUsers");
	ProfileDescription.Roles.Add("ReadCatalogProductsCategories");
	ProfileDescription.Roles.Add("ReadCatalogShippingAddressesForExternalUsers");
	ProfileDescription.Roles.Add("ReadCatalogDiscountCardTypes");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesWithCardBasedDiscounts");
	ProfileDescription.Roles.Add("ReadCatalogSupplierPriceTypesForExternalUsers");
	ProfileDescription.Roles.Add("ReadCatalogUOM");
	ProfileDescription.Roles.Add("ReadCatalogUOMClassifier");
	ProfileDescription.Roles.Add("ViewRelatedDocuments");
	ProfileDescription.Roles.Add("UseReportSalesOrdersStatementForExternalUsers");
	ProfileDescription.Roles.Add("ReadDocumentsPaymentReceiptForExternalUsers");
	ProfileDescription.Roles.Add("ReadDocumentsCashReceiptForExternalUsers");
	ProfileDescription.Roles.Add("ReadDocumentsWorkOrderForExternalUsers");
	ProfileDescription.Roles.Add("AddEditInformationRegisterQuotationKanbanStatuses");
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies"		, "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("FilesGroup"		, "AllDeniedByDefault");
	ProfileDescription.AccessKinds.Add("ProductGroups"	, "AllAllowedByDefault");
	ProfileDescription.AccessKinds.Add("BusinessUnits"	, "AllAllowedByDefault");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

#Region AccountingAdministrator
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Accounting" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name = "AccountingAdministrator";
	ProfileDescription.ID = "3cf9a90e-3cfc-4305-b7fb-bfca69316a7f";
	ProfileDescription.Description = NStr("en = 'Accounting administrator'; ru = 'Администратор бухгалтерского учета';pl = 'Administrator księgowości';es_ES = 'Administrador de contabilidad';es_CO = 'Administrador de contabilidad';tr = 'Muhasebe yöneticisi';it = 'Amministratore contabilità';de = 'Administrator Buchhaltung'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to operate with the Company and Analysis sections.'; ru = 'Данный профиль используется для работы с разделами Организация и Анализ';pl = 'Użyj tego profilu do pracy z sekcjami Firma i Analiza.';es_ES = 'Utilizar este perfil para operar con las secciones de Empresas y Análisis.';es_CO = 'Utilizar este perfil para operar con las secciones de Empresas y Análisis.';tr = 'İş yeri ve Analiz bölümleriyle çalışmak için bu profili kullanın.';it = 'Utilizzare questo profilo per operare con le sezioni Azienda e Analisi.';de = 'Verwenden Sie dieses Profil, um mit den Bereichen Firma und Analyse zu arbeiten.'");
	
	AddReadRoles(ProfileDescription);
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");

	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	ProfileDescription.Roles.Add("SaveUserData");

	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("SubsystemEnterprise");

	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	
	// Accounting templates
	ProfileDescription.Roles.Add("AddEditCatalogAccountingEntriesCategories");
	ProfileDescription.Roles.Add("AddEditCatalogAccountingEntriesTemplates");
	ProfileDescription.Roles.Add("AddEditCatalogAccountingTransactionsTemplates");
	ProfileDescription.Roles.Add("AddEditCatalogChartsOfAccounts");
	ProfileDescription.Roles.Add("AddEditCatalogTypesOfAccounting");
	ProfileDescription.Roles.Add("AddEditCatalogDefaultAccounts");
	ProfileDescription.Roles.Add("AddEditCatalogDefaultAccountsTypes");
	ProfileDescription.Roles.Add("AddEditCatalogAnalyticalDimensionsSets");
	
	ProfileDescription.Roles.Add("AddEditChartsOfAccountsMasterChartOfAccounts");
	
	ProfileDescription.Roles.Add("AddEditInformationRegisterAccountingPolicy");
	ProfileDescription.Roles.Add("ReadInformationRegisterMasterChartOfAccountsHistory");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingEntriesTemplatesStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterCompaniesTypesOfAccounting");
	ProfileDescription.Roles.Add("AddEditInformationRegisterAccountingSourceDocuments");
	ProfileDescription.Roles.Add("AddEditInformationRegisterAccountingTransactionDocuments");
	ProfileDescription.Roles.Add("AddEditInformationRegisterAccountingTransactionGenerationSettings");
	ProfileDescription.Roles.Add("AddEditInformationRegisterCompaniesTypesOfAccounting");
	
	ProfileDescription.Roles.Add("AddEditDocumentsAccountingTransaction");
	
	ProfileDescription.Roles.Add("AddEditChartOfCharacteristicTypesManagerialAnalyticalDimensionTypes");
	
	ProfileDescription.Roles.Add("AddEditAccountingRegisterAccountingJournalEntriesCompound");
	ProfileDescription.Roles.Add("AddEditAccountingRegisterAccountingJournalEntriesSimple");
	
	ProfileDescription.Roles.Add("ViewCommonFormArbitraryParametersChoiceForm");
	
	ProfileDescription.Roles.Add("EditAccountingEntries");
	ProfileDescription.Roles.Add("EditUseAccountingApproval");
	ProfileDescription.Roles.Add("EditAccountingModuleSettings");
	ProfileDescription.Roles.Add("EditPreventRepostingDocumentsWithApprovedAccountingEntries");
	ProfileDescription.Roles.Add("SubsystemSettings");
	ProfileDescription.Roles.Add("UseDataProcessorAdministrationPanel");
	ProfileDescription.Roles.Add("UseChangeStatusTool");
	ProfileDescription.Roles.Add("UseChartsOfAccountsChangeActions");
	ProfileDescription.Roles.Add("UseAccountingEntriesManagement");
	ProfileDescription.Roles.Add("SubsystemAccounting");
	
	ProfileDescription.Roles.Add("UseReportTrialBalanceMaster");
	ProfileDescription.Roles.Add("UseReportAccountEntries");
	ProfileDescription.Roles.Add("UseReportAccountAnalysis");
	ProfileDescription.Roles.Add("UseReportEntriesReport");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

#Region AccountingEntriesApproval
	
	////////////////////////////////////////////////////////////////////////////////
	// Description for "Accounting" profile filling.
	//
	ProfileDescription = AccessManagement.NewAccessGroupProfileDescription();
	ProfileDescription.Name = "AccountingEntriesApproval";
	ProfileDescription.ID = "ac23ecb2-817b-49fa-9adb-aadb56aa6b5e";
	ProfileDescription.Description = NStr("en = 'Accounting entries approval'; ru = 'Утверждение бухгалтерских проводок';pl = 'Zatwierdzenie wpisów księgowych';es_ES = 'Aprobación de entradas contables';es_CO = 'Aprobación de entradas contables';tr = 'Muhasebe girişleri onayı';it = 'Approvazione voci di contabilità';de = 'Genehmigung von Buchungen'", Metadata.DefaultLanguage.LanguageCode);
	ProfileDescription.Details = NStr("en = 'Use this profile to approve accounting entries.'; ru = 'Используйте этот профиль для утверждения бухгалтерских проводок.';pl = 'Używaj tego profilu do zatwierdzenia wpisów księgowych.';es_ES = 'Utiliza este perfil para aprobar entradas de diario.';es_CO = 'Utiliza este perfil para aprobar entradas de diario.';tr = 'Muhasebe girişlerini onaylamak için bu profili kullanın.';it = 'Utilizzare questo profilo per approvare le voci di contabilità.';de = 'Verwenden Sie diese Profil um Buchungen zu genehmigen.'");
	
	AddReadRoles(ProfileDescription);
	
	// SSL
	ProfileDescription.Roles.Add("BasicSSLRights");
	
	ProfileDescription.Roles.Add("StartWebClient");
	ProfileDescription.Roles.Add("StartThinClient");
	
	ProfileDescription.Roles.Add("BasicRightsDrive");
	ProfileDescription.Roles.Add("SubsystemEnterprise");
	
	// Profile access restriction kinds.
	ProfileDescription.AccessKinds.Add("Companies", "AllAllowedByDefault");
	
	// Accounting templates
	ProfileDescription.Roles.Add("ApproveAccountingEntries");
	ProfileDescription.Roles.Add("ReadCatalogChartsOfAccounts");
	ProfileDescription.Roles.Add("UseAccountingEntriesManagement");
	ProfileDescription.Roles.Add("ReadDocumentsAccountingTransaction");
	ProfileDescription.Roles.Add("ReadCatalogTypesOfAccounting");
	ProfileDescription.Roles.Add("ReadCatalogAnalyticalDimensionsSets");
	ProfileDescription.Roles.Add("ReadCatalogAccountingEntriesTemplates");
	ProfileDescription.Roles.Add("ReadCatalogAccountingTransactionsTemplates");
	
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingEntriesTemplatesStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingTransactionDocuments");
	ProfileDescription.Roles.Add("ReadInformationRegisterCompaniesTypesOfAccounting");
	ProfileDescription.Roles.Add("SubsystemAccounting");
	
	ProfileDescription.Roles.Add("AddEditAccountingRegisterAccountingJournalEntriesCompound");
	ProfileDescription.Roles.Add("AddEditAccountingRegisterAccountingJournalEntriesSimple");
	ProfileDescription.Roles.Add("ReadChartsOfAccountsMasterChartOfAccounts");
	
	ProfilesDetails.Add(ProfileDescription);
	
#EndRegion

EndProcedure

// Fills in non-standard access right dependencies of the subordinate object on the main object. For 
// example, access right dependencies of the PerformerTask task on the Job business process.
//
// Access right dependencies are used in the standard access restriction template for Object access kind.
// 1. By default, when reading a subordinate object, the right to read a leading object is checked 
//    and if there are no restrictions to read the leading object.
//    
// 2. When adding, changing, or deleting a subordinate object, a right to edit a leading object is 
//    checked and whether there are no restrictions to edit the leading object.
//    
//
// Only one variation is allowed, compared to the standard one, that is in clause "2)" checking the 
// right to edit the leading object can be replaced with checking the right to read the leading 
// object.
//
// Parameters:
//  RightsDependencies - ValueTable - with the following columns:
//   * LeadingTable - String - for example, Metadata.BusinessProcesses.Job.FullName().
//   * SubordinateTable - String - for example, Metadata.Tasks.PerformerTask.FullName().
//
Procedure OnFillAccessRightsDependencies(RightsDependencies) Export
	
	
	
EndProcedure

// Fills in description of available rights assigned to the objects of the specified types.
// 
// Parameters:
//  AvailableRights - ValueTable - a table with the following columns:
//   RightsOwner - String - a full name of the access value table.
//
//   Name - String - a right ID, for example, FoldersChange. The RightsManagement right must be 
//                  defined for the "Access rights" common form for setting rights.
//                  RightsManagement is a right to change rights by the owner checked upon opening 
//                  InformationRegister.ObjectsRightsSettings.Form.ObjectsRightsSettings.
//
//   Title - String - a right title, for example, in the ObjectsRightsSettings form:
//                  "Update.
//                  |folders".
//
//   Tooltip - String - a tooltip of the right title. For example, "Add, change, and mark folders 
//                  for deletion".
//
//   InitialValue - Boolean - an initial value of right check box when adding a new row in the 
//                  "Access rights" form.
//
//   RequiredRights - String array - names of rights required by this right. For example, the 
//                  ChangeFiles right is required by the AddFiles right.
//
//   ReadInTables - String array - full names of tables, for which this right means the Read right.
//                  You can use an asterisk ("*"), which means "for all other tables"
//                  as the Read right can depend only on the Read right, then only an asterisk ("*") makes sense
//                  (it is required for access restriction templates).
//
//   ChangeInTables - String array - full names of tables, for which this right means the Update right.
//                  You can use an asterisk ("*"), which means "for all other tables"
//                  (it is required for access restriction templates).
//
Procedure OnFillAvailableRightsForObjectsRightsSettings(AvailableRights) Export
	
EndProcedure

// Defines the user interface type used for access setup.
//
// Parameters:
//  SimplifiedInterface - Boolean - the initial value is False.
//
Procedure OnDefineAccessSettingInterface(SimplifiedInterface) Export
	
	SimplifiedInterface = Not Constants.UseExternalUsers.Get();
	
EndProcedure

// Fills in the usage of access kinds depending on functional options of the configuration, for 
// example, UseProductsAccessGroups.
//
// Parameters:
//  AccessKind - String - an access kind name specified in the OnFillAccessKinds procedure.
//  Use - Boolean - the initial value is True.
// 
Procedure OnFillAccessKindUsage(AccessKind, Usage) Export
	
	If AccessKind = "CounterpartiesGroup" Then
		Usage = Constants.UseCounterpartiesAccessGroups.Get();
	ElsIf AccessKind = "FilesGroup" Then
		Usage = Constants.UseFilesAccessGroups.Get();
	ElsIf AccessKind = "Companies" Then
		Usage = Constants.UseSeveralCompanies.Get();
	ElsIf AccessKind = "BusinessUnits" Then
		Usage = Constants.UseSeveralWarehouses.Get();
	ElsIf AccessKind = "ProductGroups" Then
		Usage = Constants.UseProductAccessGroupsForExternalUsers.Get();
	EndIf;
	
EndProcedure

// Allows to override the restriction specified in the metadata object manager module.
//
// Parameters:
//  List - MetadataObject - a list, for which restriction text return is required.
//                              Specify False for the list in the OnFillListsWithAccessRestriction 
//                              procedure, otherwise, a call will not be made.
//
//  Restriction - Structure - with the properties as for the procedures in manager modules. See the 
//                            properties in comments to the OnFillListsWithAccessRestriction procedure.
//
Procedure OnFillAccessRestriction(List, Restriction) Export
	
	
	
EndProcedure

// Fills in the list of access kinds used to set metadata object right restrictions.
// If the list of access kinds is not filled, the Access rights report displays incorrect data.
//
// Only access kinds explicitly used in access restriction templates must be filled. Access kinds 
// used in access value sets can be obtained from the current state of the AccessValuesSets 
// information register.
//
//  To prepare the procedure content automatically, use the
// developer tools for the Access management subsystem.
//
// Parameters:
//  Details - String - a multiline string of the <Table>.<Right>.<AccessKind>[.Object table] format. 
//                 For example "Document.PurchaseInvoice.Read.Companies",
//                           "Document.PurchaseInvoice.Read.Counterparties",
//                           "Document.PurchaseInvoice.Change.Companies",
//                           "Document.PurchaseInvoice.Change.Counterparties",
//                           "Document.Emails.Read.Object.Document.Emails",
//                           "Document.Emails.Change.Object.Document.Emails",
//                           "Document.Files.Read.Object.Catalog.FilesFolders",
//                           "Document.Files.Read.Object.Document.Email",
//                           "Document.Files.Change.Object.Catalog.FilesFolders",
//                           "Document.Files.Change.Object.Document.Email".
//                 Access kind Object is predefined as a literal. This access kind is used in access 
//                 restriction templates as a reference to another object used for applying 
//                 restrictions to the current table item.
//                 When the Object access kind is set, set table types used for this access kind.
//                  That means to enumerate types corresponding to the field used in the access 
//                 restriction template together with the "Object" access kind.
//                  When listing types by the Object access kind,
//                 list only those field types that the InformationRegisters.AccessValuesSets.Object 
//                 field has, other types are excess.
// 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(Details) Export
	
	Details = Details + "
	|AccountingRegister.AccountingJournalEntries.Read.Companies
	|AccountingRegister.FinancialJournalEntries.Read.Companies
	|AccumulationRegister.AccountsPayable.Read.Companies
	|AccumulationRegister.AccountsPayable.Read.CounterpartiesGroup
	|AccumulationRegister.AccountsReceivable.Read.Companies
	|AccumulationRegister.AccountsReceivable.Read.CounterpartiesGroup
	|AccumulationRegister.Backorders.Read.BusinessUnits
	|AccumulationRegister.Backorders.Read.Companies
	|AccumulationRegister.Backorders.Read.CounterpartiesGroup
	|AccumulationRegister.CashAssets.Read.CashAccounts
	|AccumulationRegister.CashAssets.Read.Companies
	|AccumulationRegister.CashInCashRegisters.Read.Companies
	|AccumulationRegister.EarningsAndDeductions.Read.Companies
	|AccumulationRegister.EmployeeTasks.Read.Companies
	|AccumulationRegister.EmployeeTasks.Read.CounterpartiesGroup
	|AccumulationRegister.FixedAssets.Read.Companies
	|AccumulationRegister.FixedAssetUsage.Read.Companies
	|AccumulationRegister.GoodsInvoicedNotReceived.Read.BusinessUnits
	|AccumulationRegister.GoodsInvoicedNotReceived.Read.Companies
	|AccumulationRegister.GoodsInvoicedNotReceived.Read.CounterpartiesGroup
	|AccumulationRegister.GoodsInvoicedNotShipped.Read.BusinessUnits
	|AccumulationRegister.GoodsInvoicedNotShipped.Read.Companies
	|AccumulationRegister.GoodsInvoicedNotShipped.Read.CounterpartiesGroup
	|AccumulationRegister.GoodsReceivedNotInvoiced.Read.BusinessUnits
	|AccumulationRegister.GoodsReceivedNotInvoiced.Read.Companies
	|AccumulationRegister.GoodsReceivedNotInvoiced.Read.CounterpartiesGroup
	|AccumulationRegister.GoodsShippedNotInvoiced.Read.BusinessUnits
	|AccumulationRegister.GoodsShippedNotInvoiced.Read.Companies
	|AccumulationRegister.GoodsShippedNotInvoiced.Read.CounterpartiesGroup
	|AccumulationRegister.IncomeAndExpenses.Read.Companies
	|AccumulationRegister.IncomeAndExpenses.Read.CounterpartiesGroup
	|AccumulationRegister.Inventory.Read.BusinessUnits
	|AccumulationRegister.Inventory.Read.Companies
	|AccumulationRegister.InventoryCostLayer.Read.BusinessUnits
	|AccumulationRegister.InventoryCostLayer.Read.Companies
	|AccumulationRegister.InventoryDemand.Read.Companies
	|AccumulationRegister.InventoryDemand.Read.CounterpartiesGroup
	|AccumulationRegister.InventoryFlowCalendar.Read.BusinessUnits
	|AccumulationRegister.InventoryFlowCalendar.Read.Companies
	|AccumulationRegister.InventoryFlowCalendar.Read.CounterpartiesGroup
	|AccumulationRegister.InventoryInWarehouses.Read.BusinessUnits
	|AccumulationRegister.InventoryInWarehouses.Read.Companies
	|AccumulationRegister.InvoicesAndOrdersPayment.Read.Companies
	|AccumulationRegister.InvoicesAndOrdersPayment.Read.CounterpartiesGroup
	|AccumulationRegister.LandedCosts.Read.BusinessUnits
	|AccumulationRegister.LandedCosts.Read.Companies
	|AccumulationRegister.LoanSettlements.Read.Companies
	|AccumulationRegister.LoanSettlements.Read.CounterpartiesGroup
	|AccumulationRegister.MiscellaneousPayable.Read.Companies
	|AccumulationRegister.MiscellaneousPayable.Read.CounterpartiesGroup
	|AccumulationRegister.PackedOrders.Read.Companies
	|AccumulationRegister.PaymentCalendar.Read.CashAccounts
	|AccumulationRegister.PaymentCalendar.Read.Companies
	|AccumulationRegister.Payroll.Read.Companies
	// begin Drive.FullVersion
	|AccumulationRegister.ProductionOrders.Read.Companies
	// end Drive.FullVersion
	|AccumulationRegister.ProductRelease.Read.Companies
	|AccumulationRegister.ProductRelease.Read.CounterpartiesGroup
	|AccumulationRegister.PurchaseOrders.Read.BusinessUnits
	|AccumulationRegister.PurchaseOrders.Read.Companies
	|AccumulationRegister.PurchaseOrders.Read.CounterpartiesGroup
	|AccumulationRegister.Purchases.Read.Companies
	|AccumulationRegister.Purchases.Read.CounterpartiesGroup
	|AccumulationRegister.ReservedProducts.Read.BusinessUnits
	|AccumulationRegister.ReservedProducts.Read.Companies
	|AccumulationRegister.ReservedProducts.Read.CounterpartiesGroup
	|AccumulationRegister.Sales.Read.Companies
	|AccumulationRegister.Sales.Read.CounterpartiesGroup
	|AccumulationRegister.SalesOrders.Read.BusinessUnits
	|AccumulationRegister.SalesOrders.Read.Companies
	|AccumulationRegister.SalesOrders.Read.CounterpartiesGroup
	|AccumulationRegister.SalesTarget.Read.Companies
	|AccumulationRegister.SalesTarget.Read.CounterpartiesGroup
	|AccumulationRegister.SerialNumbers.Read.BusinessUnits
	|AccumulationRegister.SerialNumbers.Read.Companies
	|AccumulationRegister.StockReceivedFromThirdParties.Read.Companies
	|AccumulationRegister.StockReceivedFromThirdParties.Read.CounterpartiesGroup
	|AccumulationRegister.StockTransferredToThirdParties.Read.Companies
	|AccumulationRegister.StockTransferredToThirdParties.Read.CounterpartiesGroup
	|AccumulationRegister.TaxPayable.Read.Companies
	|AccumulationRegister.Timesheet.Read.Companies
	|AccumulationRegister.TransferOrders.Read.BusinessUnits
	|AccumulationRegister.TransferOrders.Read.Companies
	|AccumulationRegister.VATIncurred.Read.Companies
	|AccumulationRegister.VATIncurred.Read.CounterpartiesGroup
	|AccumulationRegister.VATInput.Read.Companies
	|AccumulationRegister.VATInput.Read.CounterpartiesGroup
	|AccumulationRegister.VATOutput.Read.Companies
	|AccumulationRegister.VATOutput.Read.CounterpartiesGroup
	// begin Drive.FullVersion
	|AccumulationRegister.WorkInProgress.Read.Companies
	// end Drive.FullVersion
	|AccumulationRegister.WorkOrders.Read.Companies
	|AccumulationRegister.WorkOrders.Read.CounterpartiesGroup
	|BusinessProcess.Job.Read.Users
	|BusinessProcess.Job.Update.Users
	|Catalog.AdditionalReportsAndDataProcessors.Read.AdditionalReportsAndDataProcessors
	|Catalog.BankAccounts.Read.Companies
	|Catalog.BankAccounts.Update.Companies
	|Catalog.BankAccounts.Update.CounterpartiesGroup
	|Catalog.BankAccounts.Read.CounterpartiesGroup
	|Catalog.BusinessUnits.Update.BusinessUnits
	|Catalog.BusinessUnits.Read.BusinessUnits
	|Catalog.BusinessUnits.Read.Companies
	|Catalog.BusinessUnits.Update.Companies
	|Catalog.CashAccounts.Read.CashAccounts
	|Catalog.CashAccounts.Update.CashAccounts
	|Catalog.CashRegisters.Read.Companies
	|Catalog.Cells.Update.BusinessUnits
	|Catalog.Cells.Read.BusinessUnits
	|Catalog.Companies.Update.Companies
	|Catalog.Companies.Read.Companies
	|Catalog.ContactPersons.Read.CounterpartiesGroup
	|Catalog.ContactPersons.Update.CounterpartiesGroup
	|Catalog.Counterparties.Read.CounterpartiesGroup
	|Catalog.Counterparties.Update.CounterpartiesGroup
	|Catalog.CounterpartiesAccessGroups.Read.CounterpartiesGroup
	|Catalog.CounterpartyContracts.Update.Companies
	|Catalog.CounterpartyContracts.Read.Companies
	|Catalog.CounterpartyContracts.Update.CounterpartiesGroup
	|Catalog.CounterpartyContracts.Read.CounterpartiesGroup
	|Catalog.EmailAccounts.Read.EmailAccounts
	|Catalog.EmailAccounts.Read.Users
	|Catalog.EmailAccounts.Update.Users
	|Catalog.ExternalUsers.Read.ExternalUsers
	|Catalog.ExternalUsers.Update.ExternalUsers
	|Catalog.ExternalUsersGroups.Read.ExternalUsers
	|Catalog.Files.Read.FilesGroup
	|Catalog.Files.Update.FilesGroup
	|Catalog.FilesAccessGroups.Read.FilesGroup
	|Catalog.ObjectPropertyValueHierarchy.Read.AdditionalInfo
	|Catalog.ObjectsPropertiesValues.Read.AdditionalInfo
	|Catalog.PriceTypes.Read.Companies
	|Catalog.ProductAccessGroupsForExternalUsers.Read.ProductGroups
	|Catalog.Projects.Read.Companies
	|Catalog.Projects.Update.Companies
	|Catalog.Projects.Read.CounterpartiesGroup
	|Catalog.Projects.Update.CounterpartiesGroup
	|Catalog.ShippingAddresses.Read.CounterpartiesGroup
	|Catalog.ShippingAddresses.Update.CounterpartiesGroup
	|Catalog.SupplierPriceTypes.Read.CounterpartiesGroup
	|Catalog.SupplierPriceTypes.Update.CounterpartiesGroup
	|Catalog.TransformationTemplates.Read.Companies
	|Catalog.TransformationTemplates.Update.Companies
	|Catalog.UserGroups.Read.Users
	|Catalog.Users.Read.Users
	|Catalog.Users.Update.Users
	|ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Read.AdditionalInfo
	|Document.AccountSalesFromConsignee.Read.Companies
	|Document.AccountSalesFromConsignee.Update.Companies
	|Document.AccountSalesFromConsignee.Read.CounterpartiesGroup
	|Document.AccountSalesFromConsignee.Update.CounterpartiesGroup
	|Document.AccountSalesToConsignor.Read.Companies
	|Document.AccountSalesToConsignor.Update.Companies
	|Document.AccountSalesToConsignor.Read.CounterpartiesGroup
	|Document.AccountSalesToConsignor.Update.CounterpartiesGroup
	|Document.AdditionalExpenses.Read.Companies
	|Document.AdditionalExpenses.Update.Companies
	|Document.AdditionalExpenses.Read.CounterpartiesGroup
	|Document.AdditionalExpenses.Update.CounterpartiesGroup
	|Document.ArApAdjustments.Update.Companies
	|Document.ArApAdjustments.Read.Companies
	|Document.ArApAdjustments.Update.CounterpartiesGroup
	|Document.ArApAdjustments.Read.CounterpartiesGroup
	|Document.BankReconciliation.Read.Companies
	|Document.BankReconciliation.Update.Companies
	|Document.Budget.Read.Companies
	|Document.Budget.Update.Companies
	|Document.BulkMail.Read.CounterpartiesGroup
	|Document.BulkMail.Update.CounterpartiesGroup
	|Document.CashInflowForecast.Read.Companies
	|Document.CashInflowForecast.Update.Companies
	|Document.CashInflowForecast.Read.CounterpartiesGroup
	|Document.CashInflowForecast.Update.CounterpartiesGroup
	|Document.CashReceipt.Update.CashAccounts
	|Document.CashReceipt.Read.CashAccounts
	|Document.CashReceipt.Read.Companies
	|Document.CashReceipt.Update.Companies
	|Document.CashReceipt.Read.CounterpartiesGroup
	|Document.CashReceipt.Update.CounterpartiesGroup
	|Document.CashTransfer.Read.CashAccounts
	|Document.CashTransfer.Update.CashAccounts
	|Document.CashTransfer.Read.Companies
	|Document.CashTransfer.Update.Companies
	|Document.CashTransferPlan.Read.CashAccounts
	|Document.CashTransferPlan.Update.CashAccounts
	|Document.CashTransferPlan.Read.Companies
	|Document.CashTransferPlan.Update.Companies
	|Document.CashVoucher.Update.CashAccounts
	|Document.CashVoucher.Read.CashAccounts
	|Document.CashVoucher.Update.Companies
	|Document.CashVoucher.Read.Companies
	|Document.CashVoucher.Read.CounterpartiesGroup
	|Document.CashVoucher.Update.CounterpartiesGroup
	|Document.CostAllocation.Read.Companies
	|Document.CostAllocation.Update.Companies
	|Document.CreditNote.Read.Companies
	|Document.CreditNote.Update.Companies
	|Document.CreditNote.Read.CounterpartiesGroup
	|Document.CreditNote.Update.CounterpartiesGroup
	|Document.CustomsDeclaration.Read.Companies
	|Document.CustomsDeclaration.Update.Companies
	|Document.CustomsDeclaration.Read.CounterpartiesGroup
	|Document.CustomsDeclaration.Update.CounterpartiesGroup
	|Document.DebitNote.Read.Companies
	|Document.DebitNote.Update.Companies
	|Document.DebitNote.Read.CounterpartiesGroup
	|Document.DebitNote.Update.CounterpartiesGroup
	|Document.EmployeeTask.Read.Companies
	|Document.EmployeeTask.Update.Companies
	|Document.EmploymentContract.Read.Companies
	|Document.EmploymentContract.Update.Companies
	|Document.Event.Read.Companies
	|Document.Event.Read.CounterpartiesGroup
	|Document.Event.Update.CounterpartiesGroup
	|Document.ExpenditureRequest.Read.Companies
	|Document.ExpenditureRequest.Update.Companies
	|Document.ExpenditureRequest.Read.CounterpartiesGroup
	|Document.ExpenditureRequest.Update.CounterpartiesGroup
	|Document.ExpenseReport.Read.Companies
	|Document.ExpenseReport.Update.Companies
	|Document.ExpenseReport.Read.CounterpartiesGroup
	|Document.ExpenseReport.Update.CounterpartiesGroup
	|Document.FixedAssetDepreciationChanges.Update.Companies
	|Document.FixedAssetDepreciationChanges.Read.Companies
	|Document.FixedAssetRecognition.Read.Companies
	|Document.FixedAssetRecognition.Update.Companies
	|Document.FixedAssetSale.Read.Companies
	|Document.FixedAssetSale.Update.Companies
	|Document.FixedAssetSale.Read.CounterpartiesGroup
	|Document.FixedAssetSale.Update.CounterpartiesGroup
	|Document.FixedAssetsDepreciation.Read.Companies
	|Document.FixedAssetsDepreciation.Update.Companies
	|Document.FixedAssetUsage.Read.Companies
	|Document.FixedAssetUsage.Update.Companies
	|Document.FixedAssetWriteOff.Read.Companies
	|Document.FixedAssetWriteOff.Update.Companies
	|Document.ForeignCurrencyExchange.Update.Companies
	|Document.ForeignCurrencyExchange.Read.Companies
	|Document.GoodsIssue.Read.BusinessUnits
	|Document.GoodsIssue.Update.BusinessUnits
	|Document.GoodsIssue.Read.Companies
	|Document.GoodsIssue.Update.Companies
	|Document.GoodsIssue.Read.CounterpartiesGroup
	|Document.GoodsIssue.Update.CounterpartiesGroup
	|Document.GoodsReceipt.Read.BusinessUnits
	|Document.GoodsReceipt.Update.BusinessUnits
	|Document.GoodsReceipt.Read.Companies
	|Document.GoodsReceipt.Update.Companies
	|Document.GoodsReceipt.Read.CounterpartiesGroup
	|Document.GoodsReceipt.Update.CounterpartiesGroup
	|Document.IntraWarehouseTransfer.Read.BusinessUnits
	|Document.IntraWarehouseTransfer.Update.BusinessUnits
	|Document.IntraWarehouseTransfer.Read.Companies
	|Document.IntraWarehouseTransfer.Update.Companies
	|Document.InventoryIncrease.Read.BusinessUnits
	|Document.InventoryIncrease.Update.BusinessUnits
	|Document.InventoryIncrease.Update.Companies
	|Document.InventoryIncrease.Read.Companies
	|Document.InventoryReservation.Read.BusinessUnits
	|Document.InventoryReservation.Update.BusinessUnits
	|Document.InventoryReservation.Read.Companies
	|Document.InventoryReservation.Update.Companies
	|Document.InventoryTransfer.Read.BusinessUnits
	|Document.InventoryTransfer.Update.BusinessUnits
	|Document.InventoryTransfer.Read.Companies
	|Document.InventoryTransfer.Update.Companies
	|Document.InventoryWriteOff.Read.BusinessUnits
	|Document.InventoryWriteOff.Update.BusinessUnits
	|Document.InventoryWriteOff.Read.Companies
	|Document.InventoryWriteOff.Update.Companies
	|Document.JobSheet.Update.Companies
	|Document.JobSheet.Read.Companies
	|Document.LetterOfAuthority.Read.Companies
	|Document.LetterOfAuthority.Update.Companies
	|Document.LoanContract.Read.Companies
	|Document.LoanContract.Update.Companies
	|Document.LoanContract.Read.CounterpartiesGroup
	|Document.LoanContract.Update.CounterpartiesGroup
	|Document.LoanInterestCommissionAccruals.Update.Companies
	|Document.LoanInterestCommissionAccruals.Read.Companies
	// begin Drive.FullVersion
	|Document.Manufacturing.Read.BusinessUnits
	|Document.Manufacturing.Read.Companies
	|Document.Manufacturing.Update.Companies
	|Document.ManufacturingOperation.Read.Companies
	|Document.ManufacturingOperation.Update.Companies
	|Document.ManufacturingOverheadsRates.Read.Companies
	|Document.ManufacturingOverheadsRates.Update.Companies
	// end Drive.FullVersion
	|Document.MonthEndClosing.Read.Companies
	|Document.MonthEndClosing.Update.Companies
	|Document.OpeningBalanceEntry.Read.Companies
	|Document.OpeningBalanceEntry.Update.Companies
	|Document.Operation.Read.Companies
	|Document.Operation.Update.Companies
	|Document.OtherExpenses.Read.Companies
	|Document.OtherExpenses.Update.Companies
	|Document.PackingSlip.Read.BusinessUnits
	|Document.PackingSlip.Update.BusinessUnits
	|Document.PackingSlip.Read.Companies
	|Document.PackingSlip.Update.Companies
	|Document.PaymentExpense.Read.Companies
	|Document.PaymentExpense.Update.Companies
	|Document.PaymentExpense.Read.CounterpartiesGroup
	|Document.PaymentExpense.Update.CounterpartiesGroup
	|Document.PaymentReceipt.Read.Companies
	|Document.PaymentReceipt.Update.Companies
	|Document.PaymentReceipt.Read.CounterpartiesGroup
	|Document.PaymentReceipt.Update.CounterpartiesGroup
	|Document.Payroll.Read.Companies
	|Document.Payroll.Update.Companies
	|Document.PayrollSheet.Update.Companies
	|Document.PayrollSheet.Read.Companies
	// begin Drive.FullVersion
	|Document.Production.Read.BusinessUnits
	|Document.Production.Read.Companies
	|Document.Production.Update.Companies
	|Document.ProductionOrder.Read.BusinessUnits
	|Document.ProductionOrder.Read.Companies
	|Document.ProductionOrder.Update.Companies
	|Document.ProductionOrder.Read.CounterpartiesGroup
	|Document.ProductionOrder.Update.CounterpartiesGroup
	// end Drive.FullVersion
	|Document.ProductReturn.Read.Companies
	|Document.ProductReturn.Update.Companies
	|Document.PurchaseOrder.Read.BusinessUnits
	|Document.PurchaseOrder.Read.Companies
	|Document.PurchaseOrder.Update.Companies
	|Document.PurchaseOrder.Read.CounterpartiesGroup
	|Document.PurchaseOrder.Update.CounterpartiesGroup
	|Document.Quote.Read.Companies
	|Document.Quote.Update.Companies
	|Document.Quote.Read.CounterpartiesGroup
	|Document.Quote.Update.CounterpartiesGroup
	|Document.ReconciliationStatement.Update.Companies
	|Document.ReconciliationStatement.Read.Companies
	|Document.ReconciliationStatement.Update.CounterpartiesGroup
	|Document.ReconciliationStatement.Read.CounterpartiesGroup
	|Document.RequestForQuotation.Read.Companies
	|Document.RequestForQuotation.Update.Companies
	|Document.RetailRevaluation.Read.Companies
	|Document.RetailRevaluation.Update.Companies
	|Document.RMARequest.Update.Companies
	|Document.RMARequest.Read.Companies
	|Document.RMARequest.Read.CounterpartiesGroup
	|Document.RMARequest.Update.CounterpartiesGroup
	|Document.SalesInvoice.Read.BusinessUnits
	|Document.SalesInvoice.Read.Companies
	|Document.SalesInvoice.Update.Companies
	|Document.SalesInvoice.Read.CounterpartiesGroup
	|Document.SalesInvoice.Update.CounterpartiesGroup
	|Document.SalesOrder.Read.BusinessUnits
	|Document.SalesOrder.Read.Companies
	|Document.SalesOrder.Update.Companies
	|Document.SalesOrder.Read.CounterpartiesGroup
	|Document.SalesOrder.Update.CounterpartiesGroup
	|Document.SalesSlip.Read.Companies
	|Document.SalesSlip.Update.Companies
	|Document.SalesTarget.Read.Companies
	|Document.SalesTarget.Update.Companies
	|Document.ShiftClosure.Read.BusinessUnits
	|Document.ShiftClosure.Read.Companies
	|Document.ShiftClosure.Update.Companies
	|Document.Stocktaking.Read.BusinessUnits
	|Document.Stocktaking.Update.BusinessUnits
	|Document.Stocktaking.Update.Companies
	|Document.Stocktaking.Read.Companies
	|Document.SupplierInvoice.Read.BusinessUnits
	|Document.SupplierInvoice.Read.Companies
	|Document.SupplierInvoice.Update.Companies
	|Document.SupplierInvoice.Update.CounterpartiesGroup
	|Document.SupplierInvoice.Read.CounterpartiesGroup
	|Document.SupplierQuote.Read.Companies
	|Document.SupplierQuote.Update.Companies
	|Document.SupplierQuote.Read.CounterpartiesGroup
	|Document.SupplierQuote.Update.CounterpartiesGroup
	|Document.TaxAccrual.Read.Companies
	|Document.TaxAccrual.Update.Companies
	|Document.TaxInvoiceIssued.Read.Companies
	|Document.TaxInvoiceIssued.Update.Companies
	|Document.TaxInvoiceIssued.Read.CounterpartiesGroup
	|Document.TaxInvoiceIssued.Update.CounterpartiesGroup
	|Document.TaxInvoiceReceived.Read.Companies
	|Document.TaxInvoiceReceived.Update.Companies
	|Document.TaxInvoiceReceived.Read.CounterpartiesGroup
	|Document.TaxInvoiceReceived.Update.CounterpartiesGroup
	|Document.TerminationOfEmployment.Read.Companies
	|Document.TerminationOfEmployment.Update.Companies
	|Document.Timesheet.Read.Companies
	|Document.Timesheet.Update.Companies
	|Document.TransferAndPromotion.Update.Companies
	|Document.TransferAndPromotion.Read.Companies
	|Document.TransferOrder.Update.BusinessUnits
	|Document.TransferOrder.Read.BusinessUnits
	|Document.TransferOrder.Read.Companies
	|Document.TransferOrder.Update.Companies
	|Document.Transformation.Read.Companies
	|Document.Transformation.Update.Companies
	|Document.WeeklyTimesheet.Update.Companies
	|Document.WeeklyTimesheet.Read.Companies
	|Document.WorkOrder.Read.BusinessUnits
	|Document.WorkOrder.Read.Companies
	|Document.WorkOrder.Update.Companies
	|Document.WorkOrder.Read.CounterpartiesGroup
	|Document.WorkOrder.Update.CounterpartiesGroup
	|DocumentJournal.BankDocuments.Read.Companies
	|DocumentJournal.BankDocuments.Read.CounterpartiesGroup
	|DocumentJournal.CashDocuments.Read.CashAccounts
	|DocumentJournal.CashDocuments.Read.Companies
	|DocumentJournal.CashDocuments.Read.CounterpartiesGroup
	|DocumentJournal.CashExpenseDocuments.Read.CashAccounts
	|DocumentJournal.CashExpenseDocuments.Read.Companies
	|DocumentJournal.CashExpenseDocuments.Read.CounterpartiesGroup
	|DocumentJournal.CashFlowForecastDocuments.Read.Companies
	|DocumentJournal.CashFlowForecastDocuments.Read.CounterpartiesGroup
	|DocumentJournal.CashReceiptDocuments.Read.CashAccounts
	|DocumentJournal.CashReceiptDocuments.Read.Companies
	|DocumentJournal.CashReceiptDocuments.Read.CounterpartiesGroup
	|DocumentJournal.FixedAssetsDocuments.Read.Companies
	|DocumentJournal.HRMDocuments.Read.Companies
	|DocumentJournal.PayrollDocuments.Read.Companies
	|DocumentJournal.SalesDocuments.Read.Companies
	|DocumentJournal.SalesDocuments.Read.CounterpartiesGroup
	|DocumentJournal.SalesSlips.Read.Companies
	|DocumentJournal.ScheduledDocuments.Read.Companies
	|DocumentJournal.StocktakingDocuments.Read.BusinessUnits
	|DocumentJournal.StocktakingDocuments.Read.Companies
	|InformationRegister.AccountingPolicy.Read.Companies
	|InformationRegister.AccountingPolicy.Update.Companies
	|InformationRegister.AdditionalInfo.Read.AdditionalInfo
	|InformationRegister.AdditionalInfo.Update.AdditionalInfo
	|InformationRegister.CompensationPlan.Read.Companies
	|InformationRegister.CounterpartiesGLAccounts.Read.Companies
	|InformationRegister.CounterpartiesGLAccounts.Update.Companies
	|InformationRegister.CounterpartyPrices.Read.CounterpartiesGroup
	|InformationRegister.CounterpartyPrices.Update.CounterpartiesGroup
	|InformationRegister.Employees.Read.Companies
	|InformationRegister.ExchangeRate.Read.Companies
	|InformationRegister.FixedAssetParameters.Read.Companies
	|InformationRegister.FixedAssetStatus.Read.Companies
	|InformationRegister.HeadcountBudget.Read.Companies
	|InformationRegister.HeadcountBudget.Update.Companies
	|InformationRegister.Prices.Read.Companies
	|InformationRegister.ProductGLAccounts.Read.Companies
	|InformationRegister.ProductGLAccounts.Update.Companies
	|InformationRegister.ReorderPointSettings.Read.Companies
	|InformationRegister.ReorderPointSettings.Update.Companies
	|InformationRegister.UserGroupCompositions.Read.ExternalUsers
	|InformationRegister.UserGroupCompositions.Read.Users
	|Task.PerformerTask.Read.Users
	|Task.PerformerTask.Update.Users
	|";
	
EndProcedure

// Allows to overwrite dependent access value sets of other objects.
//
// Called from procedures
//  AccessManagementInternal.WriteAccessValuesSets,
//  AccessManagementInternal.WriteDependentAccessValuesSets.
//
// Parameters:
//  Ref - CatalogRef, DocumentRef, ... - a reference to the object, for which access value sets are 
//                 written.
//
//  RefsToDependentObjects - Array - an array of elements like CatalogRef, DocumentRef, ...
//                 Contains references to objects with dependent access value sets.
//                 Initial value is a blank array.
//
Procedure OnChangeAccessValuesSets(Ref, RefsToDependentObjects) Export
	
	
	
EndProcedure

#EndRegion

#Region Private

Procedure AddReadRoles(ProfileDescription)
	
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAccountsReceivable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterActualSalesVolume");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterAutomaticDiscountsApplied");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterBackorders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterBankReconciliation");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterCashInCashRegisters");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterCostOfSubcontractorGoods");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterCustomerOwnedInventory");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterEmployeeTasks");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterFundsTransfersBeingProcessed");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsAwaitingCustomsClearance");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInTransit");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInvoicedNotReceived");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsInvoicedNotShipped");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsReceivedNotInvoiced");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterGoodsShippedNotInvoiced");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventory");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryCostLayer");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryDemand");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryFlowCalendar");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInventoryInWarehouses");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterInvoicesAndOrdersPayment");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterLandedCosts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterMiscellaneousPayable");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterOrdersByFulfillmentMethod");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPackedOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPaymentCalendar");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterProductionOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPurchaseOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterPurchases");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterQuotations");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterReservedProducts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSales");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesTarget");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSalesWithCardBasedDiscounts");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSerialNumbers");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterStockReceivedFromThirdParties");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterStockTransferredToThirdParties");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractComponents");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractorOrdersIssued");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractorPlanning");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterThirdPartyPayments");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterTransferOrders");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterVATIncurred");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterVATInput");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterVATOutput");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterWorkOrders");
	ProfileDescription.Roles.Add("ReadCatalogActivityTypes");
	ProfileDescription.Roles.Add("ReadCatalogAutomaticDiscountTypes");
	ProfileDescription.Roles.Add("ReadCatalogBatchSettings");
	ProfileDescription.Roles.Add("ReadCatalogBatchTrackingPolicies");
	ProfileDescription.Roles.Add("ReadCatalogBillsOfMaterials");
	ProfileDescription.Roles.Add("ReadCatalogBusinessUnits");
	ProfileDescription.Roles.Add("ReadCatalogCashAccounts");
	ProfileDescription.Roles.Add("ReadCatalogCashierWorkplaceSettings");
	ProfileDescription.Roles.Add("ReadCatalogCashRegisters");
	ProfileDescription.Roles.Add("ReadCatalogCells");
	ProfileDescription.Roles.Add("ReadCatalogCompanies");
	ProfileDescription.Roles.Add("ReadCatalogCompanyResources");
	ProfileDescription.Roles.Add("ReadCatalogCompanyResourceTypes");
	ProfileDescription.Roles.Add("ReadCatalogContactPersons");
	ProfileDescription.Roles.Add("ReadCatalogContactPersonsRoles");
	ProfileDescription.Roles.Add("ReadCatalogContainerTypes");
	ProfileDescription.Roles.Add("ReadCatalogContractForms");
	ProfileDescription.Roles.Add("ReadCatalogCounterparties");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartiesAccessGroups");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartyContracts");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartyContractTypes");
	ProfileDescription.Roles.Add("ReadCatalogCounterpartySegments");
	ProfileDescription.Roles.Add("ReadCatalogCustomerAcquisitionChannels");
	ProfileDescription.Roles.Add("ReadCatalogDirectDebitMandates");
	ProfileDescription.Roles.Add("ReadCatalogDiscountCards");
	ProfileDescription.Roles.Add("ReadCatalogDiscountCardsTemplates");
	ProfileDescription.Roles.Add("ReadCatalogDiscountCardTypes");
	ProfileDescription.Roles.Add("ReadCatalogDiscountConditions");
	ProfileDescription.Roles.Add("ReadCatalogDiscountTypes");
	ProfileDescription.Roles.Add("ReadCatalogEarningAndDeductionTypes");
	ProfileDescription.Roles.Add("ReadCatalogEstimatesTemplates");
	ProfileDescription.Roles.Add("ReadCatalogFixedAssets");
	ProfileDescription.Roles.Add("ReadCatalogHSCodes");
	ProfileDescription.Roles.Add("ReadCatalogIncoterms");
	ProfileDescription.Roles.Add("ReadCatalogIndividuals");
	ProfileDescription.Roles.Add("ReadCatalogJobAndEventStatuses");
	ProfileDescription.Roles.Add("ReadCatalogKitOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogLabelsAndTagsTemplates");
	ProfileDescription.Roles.Add("ReadCatalogLeads");
	ProfileDescription.Roles.Add("ReadCatalogLegalDocuments");
	ProfileDescription.Roles.Add("ReadCatalogLegalForms");
	ProfileDescription.Roles.Add("ReadCatalogPaymentMethods");
	ProfileDescription.Roles.Add("ReadCatalogPaymentTermsTemplates");
	ProfileDescription.Roles.Add("ReadCatalogPOSTerminals");
	ProfileDescription.Roles.Add("ReadCatalogPriceGroups");
	ProfileDescription.Roles.Add("ReadCatalogPriceLists");
	ProfileDescription.Roles.Add("ReadCatalogPriceTypes");
	ProfileDescription.Roles.Add("ReadCatalogProductionOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogProducts");
	ProfileDescription.Roles.Add("ReadCatalogProductsBatches");
	ProfileDescription.Roles.Add("ReadCatalogProductsCategories");
	ProfileDescription.Roles.Add("ReadCatalogProductsCharacteristics");
	ProfileDescription.Roles.Add("ReadCatalogProjectPhases");
	ProfileDescription.Roles.Add("ReadCatalogProjects");
	ProfileDescription.Roles.Add("ReadCatalogPurchaseOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogQuotationStatuses");
	ProfileDescription.Roles.Add("ReadCatalogSalesGoalSettings");
	ProfileDescription.Roles.Add("ReadCatalogSalesOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogSalesTaxRates");
	ProfileDescription.Roles.Add("ReadCatalogSalesTerritories");
	ProfileDescription.Roles.Add("ReadCatalogSerialNumbers");
	ProfileDescription.Roles.Add("ReadCatalogShippingAddresses");
	ProfileDescription.Roles.Add("ReadCatalogSubcontractorOrderIssuedStatuses");
	ProfileDescription.Roles.Add("ReadCatalogSubscriptionPlans");
	ProfileDescription.Roles.Add("ReadCatalogSupplierPriceTypes");
	ProfileDescription.Roles.Add("ReadCatalogSuppliersProducts");
	ProfileDescription.Roles.Add("ReadCatalogTags");
	ProfileDescription.Roles.Add("ReadCatalogTeams");
	ProfileDescription.Roles.Add("ReadCatalogTransferOrderStatuses");
	ProfileDescription.Roles.Add("ReadCatalogUOM");
	ProfileDescription.Roles.Add("ReadCatalogUOMClassifier");
	ProfileDescription.Roles.Add("ReadCatalogVATRates");
	ProfileDescription.Roles.Add("ReadCatalogWorkOrderStatuses");
	ProfileDescription.Roles.Add("ReadDocumentsAccountSalesFromConsignee");
	ProfileDescription.Roles.Add("ReadDocumentsAccountSalesToConsignor");
	ProfileDescription.Roles.Add("ReadDocumentsActualSalesVolume");
	ProfileDescription.Roles.Add("ReadDocumentsAdditionalExpenses");
	ProfileDescription.Roles.Add("ReadDocumentsArApAdjustments");
	ProfileDescription.Roles.Add("ReadDocumentsByBankAndPettyCash");
	ProfileDescription.Roles.Add("ReadDocumentsCashReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsCashVoucher");
	ProfileDescription.Roles.Add("ReadDocumentsCreditNote");
	ProfileDescription.Roles.Add("ReadDocumentsCustomsDeclaration");
	ProfileDescription.Roles.Add("ReadDocumentsDebitNote");
	ProfileDescription.Roles.Add("ReadDocumentsDirectDebit");
	ProfileDescription.Roles.Add("ReadDocumentsEvent");
	ProfileDescription.Roles.Add("ReadDocumentsExpenseReport");
	ProfileDescription.Roles.Add("ReadDocumentsFixedAssetRecognition");
	ProfileDescription.Roles.Add("ReadDocumentsFixedAssetSale");
	ProfileDescription.Roles.Add("ReadDocumentsGoodsIssue");
	ProfileDescription.Roles.Add("ReadDocumentsGoodsReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsIntraWarehouseTransfer");
	ProfileDescription.Roles.Add("ReadDocumentsInventoryIncrease");
	ProfileDescription.Roles.Add("ReadDocumentsInventoryReservation");
	ProfileDescription.Roles.Add("ReadDocumentsInventoryTransfer");
	ProfileDescription.Roles.Add("ReadDocumentsInventoryWriteOff");
	ProfileDescription.Roles.Add("ReadDocumentsJournalPurchaseDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsJournalRetailDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsJournalSalesDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsJournalSalesSlips");
	ProfileDescription.Roles.Add("ReadDocumentsJournalStocktakingDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsJournalSubcontractingDocumentsForServicesReceived");
	ProfileDescription.Roles.Add("ReadDocumentsJournalTimeTrackingDocuments");
	ProfileDescription.Roles.Add("ReadDocumentsKitOrder");
	ProfileDescription.Roles.Add("ReadDocumentsKitProcessed");
	ProfileDescription.Roles.Add("ReadDocumentsMovementsOnInventory");
	ProfileDescription.Roles.Add("ReadDocumentsOnlinePayment");
	ProfileDescription.Roles.Add("ReadDocumentsOnlineReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsOpeningBalanceEntry");
	ProfileDescription.Roles.Add("ReadDocumentsPackingSlip");
	ProfileDescription.Roles.Add("ReadDocumentsPaymentExpense");
	ProfileDescription.Roles.Add("ReadDocumentsPaymentReceipt");
	ProfileDescription.Roles.Add("ReadDocumentsPricing");
	ProfileDescription.Roles.Add("ReadDocumentsProduction");
	ProfileDescription.Roles.Add("ReadDocumentsProductReturn");
	ProfileDescription.Roles.Add("ReadDocumentsPurchaseOrder");
	ProfileDescription.Roles.Add("ReadDocumentsQuote");
	ProfileDescription.Roles.Add("ReadDocumentsRetailRevaluation");
	ProfileDescription.Roles.Add("ReadDocumentsRMARequest");
	ProfileDescription.Roles.Add("ReadDocumentsSalesInvoice");
	ProfileDescription.Roles.Add("ReadDocumentsSalesOrder");
	ProfileDescription.Roles.Add("ReadDocumentsSalesSlip");
	ProfileDescription.Roles.Add("ReadDocumentsSalesTarget");
	ProfileDescription.Roles.Add("ReadDocumentsShiftClosure");
	ProfileDescription.Roles.Add("ReadDocumentsStocktaking");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorInvoiceReceived");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderIssued");
	ProfileDescription.Roles.Add("ReadDocumentsSupplierInvoice");
	ProfileDescription.Roles.Add("ReadDocumentsSupplierQuote");
	ProfileDescription.Roles.Add("ReadDocumentsTaxInvoiceIssued");
	ProfileDescription.Roles.Add("ReadDocumentsTaxInvoiceReceived");
	ProfileDescription.Roles.Add("ReadDocumentsTransferOrder");
	ProfileDescription.Roles.Add("ReadDocumentsWorkOrder");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingPolicy");
	ProfileDescription.Roles.Add("ReadInformationRegisterBarcodes");
	ProfileDescription.Roles.Add("ReadInformationRegisterBatchTrackingPolicy");
	ProfileDescription.Roles.Add("ReadInformationRegisterCounterpartyDuplicates");
	ProfileDescription.Roles.Add("ReadInformationRegisterEmailLog");
	ProfileDescription.Roles.Add("ReadInformationRegisterExchangeRate");
	ProfileDescription.Roles.Add("ReadInformationRegisterGeneratedDocumentsData");
	ProfileDescription.Roles.Add("ReadInformationRegisterGoodsDocumentsStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterInvoicesPaymentStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderFulfillmentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrderPayments");
	ProfileDescription.Roles.Add("ReadInformationRegisterOrdersPaymentSchedule");
	ProfileDescription.Roles.Add("ReadInformationRegisterPrices");
	ProfileDescription.Roles.Add("ReadInformationRegisterProductGLAccounts");
	ProfileDescription.Roles.Add("ReadInformationRegisterPurchaseOrdersStates");
	ProfileDescription.Roles.Add("ReadInformationRegisterQuotationKanbanStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterQuotationStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterReorderPointSettings");
	ProfileDescription.Roles.Add("ReadInformationRegisterServiceAutomaticDiscounts");
	ProfileDescription.Roles.Add("ReadInformationRegisterStandardTime");
	ProfileDescription.Roles.Add("ReadInformationRegisterSubstituteGoods");
	ProfileDescription.Roles.Add("ReadInformationRegisterTasksForUpdatingStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterUsingPaymentTermsInDocuments");
	ProfileDescription.Roles.Add("ReadInformationRegisterVIESVATNumberValidation");
	ProfileDescription.Roles.Add("ReadInformationRegisterWorkSchedules");
	ProfileDescription.Roles.Add("ReadInformationRegisterWorkSchedulesOfResources");
	// begin Drive.FullVersion
	ProfileDescription.Roles.Add("ReadAccumulationRegisterSubcontractorOrdersReceived");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterWorkInProgress");
	ProfileDescription.Roles.Add("ReadAccumulationRegisterWorkInProgressStatement");
	ProfileDescription.Roles.Add("ReadCatalogCostDrivers");
	ProfileDescription.Roles.Add("ReadCatalogCostPools");
	ProfileDescription.Roles.Add("ReadCatalogCostObjects");
	ProfileDescription.Roles.Add("ReadCatalogSubcontractorOrderReceivedStatuses");
	ProfileDescription.Roles.Add("ReadCatalogManufacturingActivities");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorOrderReceived");
	ProfileDescription.Roles.Add("ReadDocumentsJournalSubcontractingDocumentsForServicesProvided");
	ProfileDescription.Roles.Add("ReadDocumentsManufacturing");
	ProfileDescription.Roles.Add("ReadDocumentsManufacturingOperation");
	ProfileDescription.Roles.Add("ReadDocumentsSubcontractorInvoiceIssued");
	ProfileDescription.Roles.Add("ReadDocumentsProductionOrder");
	ProfileDescription.Roles.Add("ReadInformationRegisterProductionOperationsSequence");
	// end Drive.FullVersion
	
EndProcedure

Procedure AddAccountingRoles(ProfileDescription)
	
	ProfileDescription.Roles.Add("ReadCatalogAccountingEntriesCategories");
	ProfileDescription.Roles.Add("ReadCatalogAccountingEntriesTemplates");
	ProfileDescription.Roles.Add("ReadCatalogAccountingTransactionsTemplates");
	ProfileDescription.Roles.Add("ReadCatalogChartsOfAccounts");
	ProfileDescription.Roles.Add("ReadCatalogTypesOfAccounting");
	ProfileDescription.Roles.Add("ReadCatalogDefaultAccounts");
	ProfileDescription.Roles.Add("ReadCatalogDefaultAccountsTypes");
	ProfileDescription.Roles.Add("ReadCatalogAnalyticalDimensionsSets");
	
	ProfileDescription.Roles.Add("ReadChartsOfAccountsMasterChartOfAccounts");
	
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingPolicy");
	ProfileDescription.Roles.Add("ReadInformationRegisterMasterChartOfAccountsHistory");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingEntriesTemplatesStatuses");
	ProfileDescription.Roles.Add("ReadInformationRegisterCompaniesTypesOfAccounting");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingSourceDocuments");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingTransactionDocuments");
	ProfileDescription.Roles.Add("ReadInformationRegisterAccountingTransactionGenerationSettings");
	
	ProfileDescription.Roles.Add("AddEditDocumentsAccountingTransaction");
	
	ProfileDescription.Roles.Add("ReadChartOfCharacteristicTypesManagerialAnalyticalDimensionTypes");
	
	ProfileDescription.Roles.Add("AddEditAccountingRegisterAccountingJournalEntriesCompound");
	ProfileDescription.Roles.Add("AddEditAccountingRegisterAccountingJournalEntriesSimple");
	
	ProfileDescription.Roles.Add("ViewCommonFormArbitraryParametersChoiceForm");
	
EndProcedure

#EndRegion
