#Region Public

// Redefines the standard behavior of the Users subsystem.
//
// Parameters:
//  Settings - Structure - with the following properties:
//   * CommonAuthorizationSettings - Boolean - defines whether the administration panel will have the
//          "Users and rights settings". Authorization settings and the availability of expiration 
//          settings are available in user and external user forms.
//          It is True by default and False for basic versions of the configuration.
//
//   * EditRoles - Boolean - shows whether the role editing interface is available in profiles of 
//          users, external users, and groups of external users. This affects both regular users and 
//          administrators. Default value is True.
//
Procedure OnDefineSettings(Settings) Export
	
	
	
EndProcedure

// Allows you to specify roles, the purpose of which will be controlled in a special way.
// The majority of configuration roles here are not required, because they are intended for any 
// users except for external ones.
//
// Parameters:
//  RolesAssignment - Structure - with the following properties:
//   * ForSystemAdministratorsOnly - Array - role names that, when separation is disabled, are 
//     intended for any users other than external users, and in separated mode, are intended only 
//     for service administrators, for example:
//       Administration, DatabaseConfigurationUpdate, SystemAdministrator,
//     and also all roles with the rights:
//       Administration,
//       Administration of configuration extensions,
//       Update database configuration.
//     Such roles, as a rule, exist only in the SL and are not found in applications.
//
//   * ForSystemUsersOnly - Array - role names that, when separation is disabled, are intended for 
//     any users other than external users, and in separated mode, are intended only for 
//     non-separated users (technical support stuff and service administrators), for example:
//     
//       AddEditAddressInfo, AddEditBanks,
//     and all roles with rights to change non-separated data and those that have the following rules:
//       Thick client,
//       External connection,
//       Automation,
//       Mode "All functions",
//       Interactive open external data processors,
//       Interactive open external reports.
//     Such roles mainly exist in the SL, but can also occur in applications.
//
//   * ForExternalUsersOnly - Array - role names that are intended only for external users (roles 
//     with a specially developed set of rights), for example:
//       AddEditQuestionnaireQuestionsAnswers, BasicSSLRightsForExternalUsers.
//     Such roles exist in both the SL and applications (if external users are used).
//
//   * BothForUsersAndExternalUsers - Array - role names that are intended for any users (internal, 
//     external, and non-separated), for example:
//       ReadQuestionnaireQuestionsAnswers, AddEditPersonalReportsOptions.
//     Such roles exist in both the SL and applications (if external users are used).
//
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// ForExternalUsersOnly.
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.BasicRightsDriveForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.EditCatalogCounterpartiesForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.EditCatalogCounterpartyContractsForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.EditCatalogContactPersonsForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.EditCatalogBankAccountsForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadAccumulationRegisterAccountsPayableForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadAccumulationRegisterAccountsReceivableForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.UseReportCounterpartyContactInformationForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.UseReportCustomerStatementForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.UseReportStatementOfAccountForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadDocumentsReconciliationStatementForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadCatalogFilesForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.AddEditBusinessProcessJobForExternalUsers.Name);
	
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.PrintFormsEditForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadCatalogCompaniesForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadDocumentsQuoteForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadDocumentsGoodsIssueForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.AddDocumentsSalesOrderForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadAccumulationRegisterSalesOrdersForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadAccumulationRegisterSalesForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadAccumulationRegisterSalesForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadDocumentsSalesInvoiceForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadDocumentsTaxInvoiceIssuedForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadDocumentsCreditNoteForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.UseDataProcessorProductCartForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadCatalogDiscountCardsForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadCatalogProductAccessGroupsForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadAccumulationRegisterReservedProductsForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadCatalogShippingAddressesForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadCatalogSupplierPriceTypesForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.UseReportSalesOrdersStatementForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadDocumentsPaymentReceiptForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadDocumentsCashReceiptForExternalUsers.Name);
		
	RolesAssignment.ForExternalUsersOnly.Add(
		Metadata.Roles.ReadDocumentsWorkOrderForExternalUsers.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogQuotationStatuses.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogProducts.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogProductsCharacteristics.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogProductsBatches.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogUOM.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogBusinessUnits.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogSalesOrderStatuses.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadInformationRegisterOrderFulfillmentSchedule.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadInformationRegisterOrdersPaymentSchedule.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadInformationRegisterOrderPayments.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadInformationRegisterInvoicesPaymentStatuses.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogDiscountTypes.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadInformationRegisterPrices.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadAccumulationRegisterInventoryInWarehouses.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogProductsCategories.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogDiscountCardTypes.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadAccumulationRegisterSalesWithCardBasedDiscounts.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogUOM.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCatalogUOMClassifier.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ViewRelatedDocuments.Name);
		
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.AddEditInformationRegisterQuotationKanbanStatuses.Name);
		
EndProcedure

// Overrides the behavior of the user form, the external user form, and a group of external users, 
// when it should be different from the default behavior.
//
// For example, you need to hide, show, or allow to change or lock some properties in cases that are 
// defined by the applied logic.
//
// Parameters:
//  UserOrGroup - CatalogRef.Users,
//                          CatalogRef.ExternalUsers,
//                          CatalogRef.ExternalUsersGroups - reference to the user, external user, 
//                          or external user group at the time of form creation.
//
//  FormActions - Structure - with the following properties:
//         * Roles - String - "", "View", "Editing".
//                                             For example, when roles are edited in another form, 
//                                             you can hide them in this form or just lock editing.
//         * ContactInformation - String - "", "View", "Editing".
//                                             This property is not available for external user groups.
//                                             For example, you may need to hide contact information 
//                                             from the user with no application rights to view CI.
//         * IBUserProperties - String - "", "View", or "Editing".
//                                             This property is not available for external user groups.
//                                             For example, you may need to show infobase user 
//                                             properties for a user who has application rights for this information.
//         * ItemProperties - String - "", "View", "Editing".
//                                             For example, Description is the full name of the 
//                                             infobase user, you may need to allow editing the 
//                                             description for a user who has application rights for employee operations.
//
Procedure ChangeFormActions(Val UserOrGroup, Val FormActions) Export
	
EndProcedure

// Redefines actions that are required on infobase user writing.
// For example, if you need to synchronously update record in the matching register and so on.
// The procedure is called from the Users.WriteIBUser procedure if the user was changed.
// If the Name field in the PreviousProperties structure is not filled, a new infobase user is created.
//
// Parameters:
//  PreviousProperties - Structure - see Users.NewIBUserDetails. 
//  NewProperties - Structure - see Users.NewIBUserDetails. 
//
Procedure OnWriteInfobaseUser(Val PreviousProperties, Val NewProperties) Export
	
EndProcedure

// Redefines actions that are required after deleting an infobase user.
// For example, if you need to synchronously update record in the matching register and so on.
// The procedure is called from the DeleteIBUser() procedure if the user has been deleted.
//
// Parameters:
//  PreviousProperties - Structure - see Users.NewIBUserDetails. 
//
Procedure AfterDeleteInfobaseUser(Val PreviousProperties) Export
	
EndProcedure

// Overrides interface settings for new users.
// For example, you can set initial settings of command interface sections location.
//
// Parameters:
//  InitialSettings - Structure - the default settings:
//   * ClientSettings - ClientSettings - client application settings.
//   * InterfaceSettings - CommandInterfaceSettings - Command interface settings (for sections panel, 
//                                                                      navigation panel, and actions panel)
//   * TaxiSettings - ClientApplicationInterfaceSettings - client application interface settings 
//                                                                      (panel content and positions).
//
//   * IsExternalUser - Boolean - if True, then this is an external user.
//
Procedure OnSetInitialSettings(InitialSettings) Export
	
	InitialSettings.InterfaceSettings.SectionsPanelRepresentation = SectionsPanelRepresentation.PictureAndText;
	InitialSettings.ClientSettings.ClientApplicationInterfaceVariant = ClientApplicationInterfaceVariant.Taxi;
	
	If InitialSettings.TaxiSettings <> Undefined Then
		ContentSettings = New ClientApplicationInterfaceContentSettings;
		GroupLeft = New ClientApplicationInterfaceContentSettingsGroup;
		GroupLeft.Add(New ClientApplicationInterfaceContentSettingsItem("ToolsPanel"));
		ContentSettings.Top.Add(New ClientApplicationInterfaceContentSettingsItem("SectionsPanel"));
		ContentSettings.Bottom.Add(New ClientApplicationInterfaceContentSettingsItem("OpenItemsPanel"));
		ContentSettings.Left.Add(GroupLeft);
		InitialSettings.TaxiSettings.SetContent(ContentSettings);
	EndIf;
	
EndProcedure

// Allows you to add an arbitrary setting on the Other tab in the UsersSettings handler interface so 
// that other users can delete or copy it.
// To be able to manage the setting, write its code of copying (see OnSaveOtherSetings) and deletion 
// (see  OnDeleteOtherSettings), that will be called during interactive actions with the setting.
//
// For example, the flag that shows whether the warning should be shown when closing the application.
//
// Parameters:
//  UserInfo - Structure - string and referential user presentation.
//       * UserRef - CatalogRef.Users - a user, from which you need to receive settings.
//                               
//       * InfobaseUserName - String - an infobase user, from which you need to receive settings.
//                                             
//  Settings - Structure - other user settings.
//       * Key - String - string ID of a setting that is used for copying and clearing the setting.
//                             
//       * Value - Structure - information about settings.
//              ** SettingName - String - name to be displayed in the setting tree.
//              ** SettingPicture - Picture - picture to be displayed in the tree of settings.
//              ** SettingsList - ValueList - a list of received settings.
//
Procedure OnGetOtherSettings(UserInfo, Settings) Export
	
	
	
EndProcedure

// Saves arbitrary settings of the specified user.
// Also see OnGetOtherSettings.
//
// Parameters:
//  Settings - Structure - a structure with the fields:
//       * SettingID - String - a string of a setting to be copied.
//       * SettingValue - ValueList - a list of values of settings being copied.
//  UserInfo - Structure - string and referential user presentation.
//       * UserRef - CatalogRef.Users - a user who needs to copy a setting.
//                              
//       * InfobaseUserName - String - an infobase user.
//                                             
//
Procedure OnSaveOtherSetings(UserInfo, Settings) Export
	
	
	
EndProcedure

// Clears an arbitrary setting of a passed user.
// Also see OnGetOtherSettings.
//
// Parameters:
//  Settings - Structure - a structure with the fields:
//       * SettingID - String - a string of a setting to be cleared.
//       * SettingValue - ValueList - a list of values of settings being cleared.
//  UserInfo - Structure - string and referential user presentation.
//       * UserRef - CatalogRef.Users - a user who needs to clear a setting.
//                              
//       * InfobaseUserName - String - an infobase user.
//                                             
//
Procedure OnDeleteOtherSettings(UserInfo, Settings) Export
	
	
	
EndProcedure

#EndRegion
