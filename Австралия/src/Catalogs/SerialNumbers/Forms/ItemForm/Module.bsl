
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Owner) AND 
		NOT Object.Owner.UseSerialNumbers Then
	
		Message = New UserMessage();
		Message.Text = NStr("en = 'The product is not serialized.
		                    |Select the ""Use serial numbers"" check box in products card'; 
		                    |ru = 'Для номенклатуры не ведется учет по серийным номерам!
		                    |Установите флаг ""Использовать серийные номера"" в карточке номенклатуры';
		                    |pl = 'Produkt nie jest seryjny.
		                    |Zaznacz pole wyboru ""Użycie numerów seryjnych"" na karcie produktu';
		                    |es_ES = 'El producto no está seriado.
		                    |Seleccionar la casilla de verificación ""Utilizar números de serie"" en la tarjeta de productos';
		                    |es_CO = 'El producto no está seriado.
		                    |Seleccionar la casilla de verificación ""Utilizar números de serie"" en la tarjeta de productos';
		                    |tr = 'Ürün seri hale getirilmez. 
		                    |Ürün kartındaki ""Seri numaraları kullan "" onay kutusunu seçin';
		                    |it = 'Il prodotto non è serializzato.
		                    |Selezionare la casella di controlo ""Utilizzare numeri di serie"" nella scheda articolo';
		                    |de = 'Das Produkt wird nicht serialisiert.
		                    |Aktivieren Sie das Kontrollkästchen ""Seriennummern verwenden"" in der Produktkarte'");
		Message.Message();
		Cancel = True;
		
	EndIf;
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	If ValueIsFilled(Object.Ref) Then
		Items.GroupFill.Visible = False;
	Else
		Items.GroupFill.Visible = True;
	EndIf;
	
	If Object.Sold Then
		GuaranteeData = Catalogs.SerialNumbers.GuaranteePeriod(Object.Ref, CurrentSessionDate());
		If GuaranteeData.Count()>0 Then
			SaleInfo = ?(GuaranteeData.Guarantee, 
				String(GuaranteeData.DocumentSales)+", guarantee before"+GuaranteeData.GuaranteePeriod,
				String(GuaranteeData.DocumentSales));
			DocumentSales = GuaranteeData.DocumentSales;
		EndIf;
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If TrimAll(Object.Description)="" Then
	    Cancel = True;
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Serial number is not filled.'; ru = 'Серийный номер не заполнен.';pl = 'Numer seryjny nie jest wprowadzony.';es_ES = 'El número de serie no está rellenado.';es_CO = 'El número de serie no está rellenado.';tr = 'Seri numarası alanı doldurulmamış.';it = 'Numero di serie non compilato!';de = 'Die Seriennummer ist nicht ausgefüllt.'");
		Message.Message();
	EndIf; 
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
EndProcedure

#EndRegion

#Region Private

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

&AtServer
Procedure AddSerialNumberAtServer()
	
	Object.Description = WorkWithSerialNumbers.AddSerialNumber(Object.Owner, TemplateSerialNumber).NewNumber;
	
EndProcedure

&AtClient
Procedure AddSerialNumber(Command)
	
	AddSerialNumberAtServer();
	
EndProcedure

&AtClient
Procedure SaleInfoClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueIsFilled(DocumentSales) Then
		OpenDocumentFormByType(DocumentSales);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenDocumentFormByType(DocumentRef)
	
	FormNameString = GetDocumentNameByType(TypeOf(DocumentRef));
	OpenForm("Document."+FormNameString+".ObjectForm", New Structure("Key", DocumentRef), ThisObject);
	
EndProcedure

// Gets the document name by type at client without server call.
&AtClient
Function GetDocumentNameByType(DocumentType) Export
	
	TypesStructure = New Map;
	
	TypesStructure.Insert(Type("DocumentRef.AdditionalExpenses"),			"AdditionalExpenses");
	TypesStructure.Insert(Type("DocumentRef.AccountSalesFromConsignee"),	"AccountSalesFromConsignee");
	TypesStructure.Insert(Type("DocumentRef.Budget"),						"Budget");
	TypesStructure.Insert(Type("DocumentRef.BulkMail"),						"BulkMail");
	TypesStructure.Insert(Type("DocumentRef.ExpenditureRequest"),			"ExpenditureRequest");
	TypesStructure.Insert(Type("DocumentRef.CashVoucher"),					"CashVoucher");
	TypesStructure.Insert(Type("DocumentRef.CashReceipt"),					"CashReceipt");
	TypesStructure.Insert(Type("DocumentRef.CashTransfer"),					"CashTransfer");
	TypesStructure.Insert(Type("DocumentRef.CashTransferPlan"),				"CashTransferPlan");
	// begin Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.CostAllocation"),				"CostAllocation");
	// end Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.TerminationOfEmployment"),		"TerminationOfEmployment");
	TypesStructure.Insert(Type("DocumentRef.TransferAndPromotion"),			"TransferAndPromotion");
	TypesStructure.Insert(Type("DocumentRef.EmploymentContract"),			"EmploymentContract");
	TypesStructure.Insert(Type("DocumentRef.OpeningBalanceEntry"),			"OpeningBalanceEntry");
	TypesStructure.Insert(Type("DocumentRef.Event"),						"Event");
	TypesStructure.Insert(Type("DocumentRef.ExpenseReport"),				"ExpenseReport");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetsDepreciation"),		"FixedAssetsDepreciation");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetRecognition"),		"FixedAssetRecognition");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetDepreciationChanges"), "FixedAssetDepreciationChanges");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetUsage"),				"FixedAssetUsage");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetSale"),				"FixedAssetSale");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetWriteOff"),			"FixedAssetWriteOff");
	// begin Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.Production"),					"Production");
	TypesStructure.Insert(Type("DocumentRef.Manufacturing"),				"Manufacturing");
	// end Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.InventoryIncrease"),			"InventoryIncrease");
	TypesStructure.Insert(Type("DocumentRef.Stocktaking"),					"Stocktaking");
	TypesStructure.Insert(Type("DocumentRef.InventoryReservation"),			"InventoryReservation");
	TypesStructure.Insert(Type("DocumentRef.InventoryTransfer"),			"InventoryTransfer");
	TypesStructure.Insert(Type("DocumentRef.InventoryWriteOff"),			"InventoryWriteOff");
	TypesStructure.Insert(Type("DocumentRef.Quote"),						"Quote");
	// begin Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.JobSheet"),						"JobSheet");
	// end Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.MonthEndClosing"),				"MonthEndClosing");
	TypesStructure.Insert(Type("DocumentRef.ArApAdjustments"),				"ArApAdjustments");
	TypesStructure.Insert(Type("DocumentRef.Operation"),					"Operation");
	TypesStructure.Insert(Type("DocumentRef.OtherExpenses"),				"OtherExpenses");
	TypesStructure.Insert(Type("DocumentRef.PaymentExpense"),				"PaymentExpense");
	TypesStructure.Insert(Type("DocumentRef.PaymentReceipt"),				"PaymentReceipt");
	TypesStructure.Insert(Type("DocumentRef.CashInflowForecast"),			"CashInflowForecast");
	TypesStructure.Insert(Type("DocumentRef.Payroll"),						"Payroll");
	TypesStructure.Insert(Type("DocumentRef.PayrollSheet"),					"PayrollSheet");
	TypesStructure.Insert(Type("DocumentRef.LetterOfAuthority"),			"LetterOfAuthority");
	// begin Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.ProductionOrder"),				"ProductionOrder");
	// end Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.PurchaseOrder"),				"PurchaseOrder");
	TypesStructure.Insert(Type("DocumentRef.SalesSlip"),					"SalesSlip");
	TypesStructure.Insert(Type("DocumentRef.ProductReturn"),				"ProductReturn");
	TypesStructure.Insert(Type("DocumentRef.RegistersCorrection"),			"RegistersCorrection");
	TypesStructure.Insert(Type("DocumentRef.AccountSalesToConsignor"),		"AccountSalesToConsignor");
	TypesStructure.Insert(Type("DocumentRef.ShiftClosure"),					"ShiftClosure");
	TypesStructure.Insert(Type("DocumentRef.RetailRevaluation"),			"RetailRevaluation");
	TypesStructure.Insert(Type("DocumentRef.SalesInvoice"),					"SalesInvoice");
	TypesStructure.Insert(Type("DocumentRef.SalesOrder"),					"SalesOrder");
	TypesStructure.Insert(Type("DocumentRef.SalesTarget"),					"SalesTarget");
	TypesStructure.Insert(Type("DocumentRef.ReconciliationStatement"),		"ReconciliationStatement");
	TypesStructure.Insert(Type("DocumentRef.SupplierInvoice"),				"SupplierInvoice");
	TypesStructure.Insert(Type("DocumentRef.SupplierQuote"),				"SupplierQuote");
	TypesStructure.Insert(Type("DocumentRef.TaxAccrual"),					"TaxAccrual");
	TypesStructure.Insert(Type("DocumentRef.Timesheet"),					"Timesheet");
	// begin Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.WeeklyTimesheet"),				"WeeklyTimesheet");
	// end Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.IntraWarehouseTransfer"),		"IntraWarehouseTransfer");
	// begin Drive.FullVersion
	TypesStructure.Insert(Type("DocumentRef.EmployeeTask"),					"WorkOrder");
	// end Drive.FullVersion
	
	Return TypesStructure.Get(DocumentType);

EndFunction

#EndRegion