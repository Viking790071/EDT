#Region Public

// Overrides subsystem settings.
//
// Parameters:
//  Settings - Structure - subsystem settings:
//   * UseSignaturesAndSeals - Boolean - if it is set to False, the option to set signatures and 
//                                           seals in print forms is disabled.
//   * HideSignaturesAndSealsForEditing - Boolean - delete pictures of spreadsheet document 
//                                           signatures and seals upon clearing the "Signatures and 
//                                           Seals" checkbox in the "Print documents" form so that they do not interfere with editing the text below them.
//
Procedure OnDefinePrintSettings(Settings) Export
	
	Settings.UseSignaturesAndSeals = False;
	
EndProcedure

// Defines configuration objects, in whose manager modules the AddPrintCommands procedure is placed. 
// The procedure generates a print command list provided by this object.
// See syntax of the AddPrintCommands procedure in the subsystem documentation.
//
// Parameters:
//  ObjectsList - Array - object managers with the AddPrintCommands procedure.
//
Procedure OnDefineObjectsWithPrintCommands(ObjectsList) Export
	
	// Catalogs
	ObjectsList.Add(Catalogs.CounterpartyContracts);
	ObjectsList.Add(Catalogs.DirectDebitMandates);
	
	// Documents
	ObjectsList.Add(Documents.AccountingTransaction);
	ObjectsList.Add(Documents.AccountSalesFromConsignee);
	ObjectsList.Add(Documents.AccountSalesToConsignor);
	ObjectsList.Add(Documents.AdditionalExpenses);
	ObjectsList.Add(Documents.ArApAdjustments);
	ObjectsList.Add(Documents.Budget);
	ObjectsList.Add(Documents.CashInflowForecast);
	ObjectsList.Add(Documents.CashReceipt);
	ObjectsList.Add(Documents.CashTransfer);
	ObjectsList.Add(Documents.CashTransferPlan);
	ObjectsList.Add(Documents.CashVoucher);
	// begin Drive.FullVersion
	ObjectsList.Add(Documents.CostAllocation);
	// end Drive.FullVersion
	ObjectsList.Add(Documents.CreditNote);
	ObjectsList.Add(Documents.CustomsDeclaration);
	ObjectsList.Add(Documents.DebitNote);
	ObjectsList.Add(Documents.DirectDebit);
	ObjectsList.Add(Documents.EmploymentContract);
	ObjectsList.Add(Documents.ExpenditureRequest);
	ObjectsList.Add(Documents.ExpenseReport);
	ObjectsList.Add(Documents.FixedAssetDepreciationChanges);
	ObjectsList.Add(Documents.FixedAssetRecognition);
	ObjectsList.Add(Documents.FixedAssetSale);
	ObjectsList.Add(Documents.FixedAssetsDepreciation);
	ObjectsList.Add(Documents.FixedAssetUsage);
	ObjectsList.Add(Documents.FixedAssetWriteOff);
	ObjectsList.Add(Documents.ForeignCurrencyExchange);
	ObjectsList.Add(Documents.GoodsIssue);
	ObjectsList.Add(Documents.GoodsReceipt);
	ObjectsList.Add(Documents.IntraWarehouseTransfer);
	ObjectsList.Add(Documents.InventoryIncrease);
	ObjectsList.Add(Documents.InventoryReservation);
	ObjectsList.Add(Documents.InventoryTransfer);
	ObjectsList.Add(Documents.InventoryWriteOff);
	// begin Drive.FullVersion
	ObjectsList.Add(Documents.JobSheet);
	// end Drive.FullVersion
	ObjectsList.Add(Documents.KitOrder);
	ObjectsList.Add(Documents.LetterOfAuthority);
	ObjectsList.Add(Documents.LoanContract);
	ObjectsList.Add(Documents.LoanInterestCommissionAccruals);
	// begin Drive.FullVersion
	ObjectsList.Add(Documents.EmployeeTask);
	// end Drive.FullVersion
	ObjectsList.Add(Documents.OnlineReceipt);
	ObjectsList.Add(Documents.OpeningBalanceEntry);
	ObjectsList.Add(Documents.OtherExpenses);
	ObjectsList.Add(Documents.PackingSlip);
	ObjectsList.Add(Documents.PaymentExpense);
	ObjectsList.Add(Documents.PaymentReceipt);
	ObjectsList.Add(Documents.Payroll);
	ObjectsList.Add(Documents.PayrollSheet);
	ObjectsList.Add(Documents.Production);
	// begin Drive.FullVersion
	ObjectsList.Add(Documents.Manufacturing);
	// end Drive.FullVersion
	ObjectsList.Add(Documents.PackingSlip);
	// begin Drive.FullVersion
	ObjectsList.Add(Documents.ProductionOrder);
	ObjectsList.Add(Documents.ProductionTask);
	// end Drive.FullVersion
	ObjectsList.Add(Documents.ProductReturn);
	ObjectsList.Add(Documents.PurchaseOrder);
	ObjectsList.Add(Documents.Quote);
	ObjectsList.Add(Documents.ReconciliationStatement);
	ObjectsList.Add(Documents.RequestForQuotation);
	ObjectsList.Add(Documents.RequisitionOrder);
	ObjectsList.Add(Documents.RetailRevaluation);
	ObjectsList.Add(Documents.RMARequest);
	ObjectsList.Add(Documents.SalesInvoice);
	ObjectsList.Add(Documents.SalesOrder);
	ObjectsList.Add(Documents.SalesSlip);
	ObjectsList.Add(Documents.SalesTarget);
	ObjectsList.Add(Documents.ShiftClosure);
	ObjectsList.Add(Documents.Stocktaking);
	ObjectsList.Add(Documents.SupplierInvoice);
	ObjectsList.Add(Documents.TaxAccrual);
	ObjectsList.Add(Documents.TaxInvoiceIssued);
	ObjectsList.Add(Documents.TaxInvoiceReceived);
	ObjectsList.Add(Documents.TerminationOfEmployment);
	ObjectsList.Add(Documents.Timesheet);
	ObjectsList.Add(Documents.TransferAndPromotion);
	ObjectsList.Add(Documents.TransferOrder);
	ObjectsList.Add(Documents.VATInvoiceForICT);
	// begin Drive.FullVersion
	ObjectsList.Add(Documents.WeeklyTimesheet);
	// end Drive.FullVersion
	ObjectsList.Add(Documents.WorkOrder);
	
EndProcedure

// Overrides the table of available formats for saving a spreadsheet document.
// Used to shorten the list of save formats offered to users before saving a print form to file or 
// before sending by email.
//
// Parameters:
//  FormatsTable - ValueTable - a collection of save formats:
//   * SpreadsheetDocumentFileType - SpreadsheetDocumentFileType - a value in the platform that corresponds to the format.
//   * Ref - EnumRef.ReportsSaveFormats - a reference to metadata, where the presentation is stored.
//   * Presentation - String - a file type presentation (filled in from enumeration).
//   * Extension - String - a file type for the operating system.
//   * Picture - Picture - a format icon.
//
Procedure OnFillSpeadsheetDocumentSaveFormatsSettings(FormatsTable) Export
	
EndProcedure

// Overrides the print command list retrieved by the PrintManager.FormPrintCommands function.
// Used for common forms that do not have a manager module to place the AddPrintCommands procedure 
// in it and when the standard functionality is not enough to add commands to such forms. For 
// example, when you need your own commands that other objects do not have.
// 
// Parameters:
//  FormName - String - a full name of form, in which print commands are added.
//  PrintCommands - ValueTable - see PrintManager.CreatePrintCommandsCollection. 
//  StandardProcessing - Boolean - when setting to False, the PrintCommands collection will not be filled in automatically.
//
Procedure BeforeAddPrintCommands(FormName, PrintCommands, StandardProcessing) Export
	
EndProcedure

// Additional settings of print commands in document journals.
//
// Parameters:
//  ListSettings - Structure - print command list modifiers.
//   * PrintCommandsManager - ObjectManager - an object manager, in which the list of print commands is generated.
//   * Autofill - Boolean - filling print commands from the objects included in the journal.
//                                         If the value is False, the list of journal print commands 
//                                         will be filled by calling the AddPrintCommands method from the journal manager module.
//                                         The default value: True - the AddPrintCommands method 
//                                         will be called from the document manager modules from the journal.
Procedure OnGetPrintCommandListSettings(ListSettings) Export
	
EndProcedure

// Called after ending call of the Print object print manager procedure, it has the same parameters.
// It can be used for post-processing of all print forms when generating them.
// For example, you can insert a date of print form generation to the header or footer.
//
// Parameters:
//  ObjectsArray - Array - a list of objects, for which the Print procedure was executed.
//  PrintParameters - Structure - arbitrary parameters passed when calling the print command.
//  PrintFormsCollection - ValueTable - contains spreadsheet documents and additional information.
//  PrintObjects - ValueList - correspondence between objects and names of areas in spreadsheet 
//                                   documents, where the value is Object, and the presentation is an area name with the object in spreadsheet documents.
//  OutputParameters - Structure - parameters connected to output of spreadsheet documents:
//   * SendOptions - Structure - information to fill in the message when sending a print form by email.
//                                     Contains the following fields (see description in the common configuration module
//                                     EmailClient in the CreateNewMessage procedure):
//    ** Recipient
//    ** Subject
//    ** Text
Procedure OnPrint(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	
	
EndProcedure

// Overrides the print form send parameters when preparing a message.
// It can be used, for example, to prepare a message text.
//
// Parameters:
//  SendOptions - Structure - a collection of the following parameters:
//   * Recipient - Array - a collection of recipient names.
//   * Subject - String - an email subject.
//   * Text - String - an email text.
//   * Attachments - Structure - a collection of attachments:
//    ** AddressInTempStorage - String - an attachment address in a temporary storage.
//    ** Presentation - String - an attachment file name.
//  PrintObjects - Array - a collection of objects, by which print forms are generated.
//  OutputParameters - Structure - the OutputParameters parameter when calling the Print procedure.
//  PrintForms - ValueTable - a collection of spreadsheet documents:
//   * Name - String - a print form name.
//   * SpreadsheetDocument - SpreadsheetDocument - a print form.
Procedure BeforeSendingByEmail(SendOptions, OutputParameters, PrintObjects, PrintForms) Export
	
EndProcedure

// Defines a set of signatures and seals for documents.
//
// Parameters:
//  Document      - Array    - a collection of references to print objects.
//  SignaturesAndSeals - Map - a collection of print objects and their sets of signatures and seals.
//   * Key - AnyRef - a reference to the print object.
//   * Value - Structure - a set of signatures and seals:
//     ** Key     - String - an ID of signature or seal in print form template. It must start with 
//                            "Signature...", "Seal...", or "Facsimile", for example, 
//                            ManagerSignature or CompanySeal.
//     ** Value - Picture - a picture of signature or seal.
//
Procedure OnGetSignaturesAndSeals(Documents, SignaturesAndSeals) Export
	
	
	
EndProcedure

#EndRegion
