#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		And ValueIsFilled(Object.Counterparty)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		If Not ValueIsFilled(Object.Contract) Then
			Object.Contract = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
		EndIf;
		
		If ValueIsFilled(Object.Contract) Then
			
			ContractAttributes = Common.ObjectAttributesValues(Object.Contract, "SettlementsCurrency");
			
			If Not ValueIsFilled(Object.DocumentCurrency) Then
				
				Object.DocumentCurrency = ContractAttributes.SettlementsCurrency;
				
				CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Object.Date,
					Object.DocumentCurrency,
					Object.Company);
				
				Object.ExchangeRate = ?(CurrencyRateRepetition.ExchangeRate = 0, 1, CurrencyRateRepetition.ExchangeRate);
				Object.Multiplicity = ?(CurrencyRateRepetition.Multiplicity = 0, 1, CurrencyRateRepetition.Multiplicity);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	If Not ValueIsFilled(Object.ReceiptDate) Then
		Object.ReceiptDate = DocumentDate;
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	Counterparty = Object.Counterparty;
	Contract = Object.Contract;
	SettlementsCurrency = Object.Contract.SettlementsCurrency;
	
	ReadCounterpartyAttributes(CounterpartyAttributes, Object.Counterparty);
	
	SetAccountingPolicyValues();
	
	InProcessStatus = Constants.SubcontractorOrderIssuedInProgressStatus.Get();
	CompletedStatus = Constants.SubcontractorOrderIssuedCompletionStatus.Get();
	
	If GetFunctionalOption("UseSubcontractorOrderIssuedStatuses") Then
		
		Items.Status.Visible = False;
		
	Else
		
		Items.OrderState.Visible = False;
		
		StatusesStructure = Documents.SubcontractorOrderIssued.GetSubcontractorOrderStringStatuses();
		
		For Each Item In StatusesStructure Do
			Items.Status.ChoiceList.Add(Item.Key, Item.Value);
		EndDo;
		
		ResetStatus();
		
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		And Not ValueIsFilled(Parameters.Basis)
		And Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation();
		
	Else
		
		TaxVisible = (Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT);
		
		Items.ProductsVATRate.Visible = TaxVisible;
		Items.ProductsVATAmount.Visible = TaxVisible;
		Items.ProductsTotal.Visible = TaxVisible;
		Items.DocumentTax.Visible = TaxVisible;
		
	EndIf;
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
	ProcessingCompanyVATNumbers();
	
	SetContractVisible();
	
	DriveClientServer.SetPictureForComment(Items.PageAdditionalInformation, Object.Comment);
	
	AccountingPrice = InformationRegisters.AccountingPolicy.GetAccountingPolicy(
		?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate()),
		Object.Company).AccountingPrice;
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.SubcontractorOrderIssued.TabularSections.Inventory,
		DataLoadSettings,
		ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnCreateAtServer(ThisObject, New Structure("ItemForPlacementName", "GroupAdditionalAttributes"));
	// End StandardSubsystems.Properties
	
	UseDataImportAccessRight = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	Items.InventoryDataImportFromExternalSources.Visible = UseDataImportAccessRight;
	Items.ByProductsDataImportFromExternalSources.Visible = UseDataImportAccessRight;
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText,
			Object.Ref,
			Object.Company,
			Object.Counterparty,
			Object.Contract,
			CounterpartyAttributes.DoOperationsByContracts,
			Cancel);
		
		If MessageText <> "" Then
			If Cancel Then
				MessageText = NStr("en = 'Document is not posted.'; ru = '???????????????? ???? ????????????????.';pl = 'Dokument niezaksi??gowany.';es_ES = 'El documento no se ha publicado.';es_CO = 'El documento no se ha publicado.';tr = 'Belge kaydedilmedi.';it = 'Il documento non ?? pubblicato.';de = 'Dokument ist nicht gebucht.'") + " " + MessageText;
				CommonClientServer.MessageToUser(MessageText, , "Object.Contract");
			Else
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	If EventName = "AfterRecordingOfCounterparty" And ValueIsFilled(Parameter) And Object.Counterparty = Parameter Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Parameter);
		
		SetContractVisible();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshGroupSubcontractorOrders", Object.Ref);

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StatusOnChange(Item)
	
	If Status = "StatusInProcess" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "StatusCompleted" Then
		Object.OrderState = CompletedStatus;
	ElsIf Status = "StatusCanceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Number = "";
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	StructureData = GetCompanyDataOnChange();
	ParentCompany = StructureData.Company;
	AccountingPrice = StructureData.AccountingPrice;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	ProcessContractChange();
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ReadCounterpartyAttributes(CounterpartyAttributes, Counterparty);
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.Counterparty, Object.Company);
		Object.Contract = StructureData.Contract;
		ProcessContractChange(StructureData);
		GenerateLabelPricesAndCurrency(ThisObject);
		
	Else
		
		Object.Contract = Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If CounterpartyAttributes.DoOperationsByContracts Then
		
		StandardProcessing = False;
		
		FormParameters = GetChoiceFormOfContractParameters(Object.Ref,
			Object.Company,
			Object.Counterparty,
			Object.Contract);
		
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractCreating(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	StructureFillingValues = New Structure;
	StructureFillingValues.Insert("Owner",			Object.Counterparty);
	StructureFillingValues.Insert("Company",		Object.Company);
	StructureFillingValues.Insert("ContractKind",	PredefinedValue("Enum.ContractType.SubcontractingServicesReceived"));
	StructureFillingValues.Insert("IsNotifyCaller",	True);
		
	FormParameters = New Structure("FillingValues", StructureFillingValues);
	
	StructureNotify = New Structure;
	ContractCreatingAfterWrite = New NotifyDescription("ContractCreatingAfterWrite", ThisObject, StructureNotify);
	
	OpenForm("Catalog.CounterpartyContracts.ObjectForm", FormParameters, ThisObject, , , , ContractCreatingAfterWrite);
	
EndProcedure

&AtClient
Procedure ContractCreatingAfterWrite(Result, StructureNotify) Export
	
	If Result.Property("Contract") 
		And ValueIsFilled(Result.Contract) Then
		
		Object.Contract = Result.Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderStateOnChange(Item)
	
	If Object.OrderState <> CompletedStatus Then 
		Object.Closed = False;
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure OrderStateStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceData = GetSubcontractorOrderStates();
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ProcessChangesOnButtonPricesAndCurrencies();
		
EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersProducts

&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("ProcessingDate", Object.Date);
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	FillPropertyValues(TabularSectionRow, StructureData);
	TabularSectionRow.Quantity			= 1;
	
	ProductsRowCalculateAmount(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	If DriveClient.UseMatrixForm(TabularSectionRow.Products) Then
		
		StandardProcessing = False;
		
		SelectionParameters = DriveClient.GetMatrixParameters(ThisObject, "Products", False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
			SelectionParameters,
			ThisObject,
			True,,,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Item)
	
	ProductsRowCalculateAmount();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsPriceOnChange(Item)
	
	ProductsRowCalculateAmount();
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsAmountOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	CalculateVATAmount(TabularSectionRow);
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsVATRateOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	CalculateVATAmount(TabularSectionRow);
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculateSubtotal();
	
EndProcedure

&AtClient
Procedure ProductsVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	RecalculateSubtotal();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersInventory

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If DriveClient.UseMatrixForm(TabularSectionRow.Products) Then
		
		StandardProcessing = False;
		
		SelectionParameters = DriveClient.GetMatrixParameters(ThisObject, "Inventory", False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
			SelectionParameters,
			ThisObject,
			True,,,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersByProducts

&AtClient
Procedure ByProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.ByProducts.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", 			TabularSectionRow.Products);
	StructureData.Insert("Characteristic",		PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef"));
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate",		Object.Date);
	StructureData.Insert("PriceKind",			AccountingPrice);
	StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
	StructureData.Insert("Factor",				1);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit	= StructureData.MeasurementUnit;
	TabularSectionRow.Quantity			= 1;
	TabularSectionRow.CostValue			= StructureData.Price;
	
	ByProductsRowCalculateTotal(TabularSectionRow);
	
	If Not ValueIsFilled(TabularSectionRow.CostValue) Then
		AccountingPriceMessage();
	EndIf;
	
EndProcedure

&AtClient
Procedure ByProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.ByProducts.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", 			TabularSectionRow.Products);
	StructureData.Insert("Characteristic", 		TabularSectionRow.Characteristic);
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate",		Object.Date);
	StructureData.Insert("PriceKind",			AccountingPrice);
	StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
	StructureData.Insert("MeasurementUnit",		TabularSectionRow.MeasurementUnit);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.CostValue = StructureData.Price;
	
	ByProductsRowCalculateTotal(TabularSectionRow);
	
	If Not ValueIsFilled(TabularSectionRow.CostValue) Then
		AccountingPriceMessage();
	EndIf;
	
EndProcedure

&AtClient
Procedure ByProductsQuantityOnChange(Item)
	
	ByProductsRowCalculateTotal();
	
EndProcedure

&AtClient
Procedure ByProductsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.ByProducts.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.CostValue = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.CostValue = TabularSectionRow.CostValue * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	ByProductsRowCalculateTotal();
	
	TabularSectionRow.MeasurementUnit = ValueSelected;
	
EndProcedure

&AtClient
Procedure ByProductsCostValueOnChange(Item)
	
	ByProductsRowCalculateTotal();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CloseOrder(Command)
	
	If Modified Or Not Object.Posted Then
		
		QueryText = NStr("en = 'The order data is not saved. The order can be closed only after its data is saved.
			|The data will be saved.'; 
			|ru = '???????????? ???????????? ???? ??????????????????. ?????????? ?????????? ???????? ???????????? ???????????? ?????????? ???????????????????? ????????????.
			|???????????? ?????????? ??????????????????.';
			|pl = 'Dane zam??wienia nie s?? zapisane. Zam??wienie mo??e by?? zamkni??te tylko po tym jak jego dane s?? zapisane.
			|Dane zostan?? zapisane.';
			|es_ES = 'Los datos de la orden no se guardan. Se puede cerrar la orden s??lo una vez que se hayan guardado los datos.
			|Los datos se guardar??n.';
			|es_CO = 'Los datos de la orden no se guardan. Se puede cerrar la orden s??lo una vez que se hayan guardado los datos.
			|Los datos se guardar??n.';
			|tr = 'Sipari?? verileri kaydedilmedi. Sipari?? ancak veriler kaydedildikten sonra kapat??labilir.
			|Veriler kaydedilecek.';
			|it = 'I dati dell''ordine non sono salvati. L''ordine pu?? essere chiuso solamente dopo averne salvato i dati. 
			|I dati saranno salvati.';
			|de = 'Die Auftragsdaten wurden nicht gespeichert. Der Auftrag kann erst geschlossen werden, nachdem die Daten gespeichert wurden.
			|Die Daten werden gespeichert.'");
		
		ShowQueryBox(New NotifyDescription("CloseOrderEnd", ThisObject), QueryText, QuestionDialogMode.OKCancel);
		
		Return;
		
	EndIf;
	
	CloseOrderFragment();
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure InventoryPick(Command)
	
	SelectionParameters = DriveClient.GetSelectionParameters(ThisObject,
		"Inventory",
		NStr("en = 'Subcontractor order issued'; ru = '???????????????? ?????????? ???? ??????????????????????';pl = 'Wydane zam??wienie wykonawcy';es_ES = 'Orden emitida del subcontratista';es_CO = 'Orden emitida del subcontratista';tr = 'Alt y??klenici sipari??i d??zenlendi';it = 'Ordine subfornitura emesso';de = 'Subunternehmerauftrag ausgestellt'"),
		False,
		False);
	
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnit);
	
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
		SelectionParameters,
		ThisObject,
		True,,,
		New NotifyDescription("OnCloseSelection", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProductsPick(Command)
	
	SelectionParameters = DriveClient.GetSelectionParameters(ThisObject,
		"Products",
		NStr("en = 'Subcontractor order issued'; ru = '???????????????? ?????????? ???? ??????????????????????';pl = 'Wydane zam??wienie wykonawcy';es_ES = 'Orden emitida del subcontratista';es_CO = 'Orden emitida del subcontratista';tr = 'Alt y??klenici sipari??i d??zenlendi';it = 'Ordine subfornitura emesso';de = 'Subunternehmerauftrag ausgestellt'"),
		False,
		False,
		False);
	
	SelectionParameters.Insert("Company", ParentCompany);
	
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
		SelectionParameters,
		ThisObject,
		True,,,
		New NotifyDescription("OnCloseSelection", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ByProductsPick(Command)
	
	SelectionParameters = DriveClient.GetSelectionParameters(ThisObject,
		"ByProducts",
		NStr("en = 'Subcontractor order issued'; ru = '???????????????? ?????????? ???? ??????????????????????';pl = 'Wydane zam??wienie wykonawcy';es_ES = 'Orden emitida del subcontratista';es_CO = 'Orden emitida del subcontratista';tr = 'Alt y??klenici sipari??i d??zenlendi';it = 'Ordine subfornitura emesso';de = 'Subunternehmerauftrag ausgestellt'"),
		False,
		False,
		False);
	
	SelectionParameters.Insert("Company", ParentCompany);
	
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
		SelectionParameters,
		ThisObject,
		True,,,
		New NotifyDescription("OnCloseSelection", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to repopulate the data for this Subcontractor order issued?'; ru = '???? ???????????? ?????????????????????????? ???????????? ?????? ?????????? ?????????????????? ???????????? ???? ???????????????????????';pl = 'Czy chcesz ponownie wype??ni?? dane dla tego wydanego zam??wienia podwykonawcy?';es_ES = '??Quiere rellenar los datos de esta orden emitida del subcontratista?';es_CO = '??Quiere rellenar los datos de esta orden emitida del subcontratista?';tr = 'Bu ""D??zenlenen alt y??klenici sipari??i"" i??in verileri yeniden doldurmak istiyor musunuz?';it = 'Ripopolare i dati per questo Ordine subfornitura emesso?';de = 'M??chten Sie die Daten f??r diesen ausgestellten Subunternehmerauftrag neu f??llen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillBySpecification(Command)
	
	If Not CheckBOMFilling() Then
		Return;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("FillBySpecificationEnd", ThisObject),
			NStr("en = 'Components will be repopulated. Do you want to continue?'; ru = '???????????????????? ?????????? ??????????????????????????. ?????????????????????';pl = 'Komponenty zostan?? ponownie wype??nione. Czy chcesz kontynuowa???';es_ES = 'Los componentes ser??n rellenados. ??Quiere continuar?';es_CO = 'Los componentes ser??n rellenados. ??Quiere continuar?';tr = 'Malzemeler yeniden doldurulacak. Devam etmek istiyor musunuz?';it = 'Le componenti saranno ricompilate. Continuare?';de = 'Materialbestand wird neu f??llt. M??chten Sie fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		FillBySpecificationFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillBySpecificationByProducts(Command)
	
	If Not CheckBOMFilling() Then
		Return;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("FillBySpecificationByProductsEnd", ThisObject),
			NStr("en = 'The data on the ""By-products"" tab will be replaced with the data from the bill of materials. Do you want to continue?'; ru = '???????????? ???? ?????????????? ""???????????????? ??????????????????"" ?????????? ???????????????? ?????????????? ???? ????????????????????????. ?????????????????????';pl = 'Dane na karcie ""Produkty uboczne"" zostan?? zast??pione danymi ze specyfikacji materia??owej. Czy chcesz kontynuowa???';es_ES = 'Los datos de la pesta??a ""Trozo y deterioro"" se reemplazar??n por los datos de la lista de materiales. ??Quiere continuar?';es_CO = 'Los datos de la pesta??a ""Trozo y deterioro"" se reemplazar??n por los datos de la lista de materiales. ??Quiere continuar?';tr = '""Yan ??r??nler"" sekmesindeki veriler ??r??n re??etesindeki verilerle de??i??tirilecek. Devam etmek istiyor musunuz?';it = 'I dati nella scheda ""Scarti e residui"" saranno sostituiti con i dati della distinta base. Continuare?';de = 'Die Daten auf der Registerkarte ""Nebenprodukte"" werden den durch die Daten aus der ausgew??hlten St??ckliste ersetzt. M??chten Sie fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		FillBySpecificationFragment(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure FillBySpecificationTakingRelatedBOMs(Command) 
	
	If Not CheckBOMFilling() Then
		Return;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("FillBySpecificationTakingRelatedBOMsEnd", ThisObject),
			NStr("en = 'Components will be repopulated. Do you want to continue?'; ru = '???????????????????? ?????????? ??????????????????????????. ?????????????????????';pl = 'Komponenty zostan?? ponownie wype??nione. Czy chcesz kontynuowa???';es_ES = 'Los componentes ser??n rellenados. ??Quiere continuar?';es_CO = 'Los componentes ser??n rellenados. ??Quiere continuar?';tr = 'Malzemeler yeniden doldurulacak. Devam etmek istiyor musunuz?';it = 'Le componenti saranno ripopolate. Continuare?';de = 'Komponenten werden neu f??llt. M??chten Sie fortfahren?'"),
			QuestionDialogMode.YesNo);
	Else
		FillBySpecificationTakingRelatedBOMsServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	NotifyDescription = New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode));
	ShowInputValue(NotifyDescription, CurBarcode, NStr("en = 'Enter barcode'; ru = '?????????????? ????????????????';pl = 'Wprowad?? kod kreskowy';es_ES = 'Introducir el c??digo de barras';es_CO = 'Introducir el c??digo de barras';tr = 'Barkod girin';it = 'Inserire codice a barre';de = 'Geben Sie den Barcode ein'"));
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined And BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure;
			StructureProductsData.Insert("Company", StructureData.Company);
			StructureProductsData.Insert("Counterparty", StructureData.Counterparty);
			StructureProductsData.Insert("VATTaxation", StructureData.VATTaxation);
			StructureProductsData.Insert("ProcessingDate", StructureData.DocumentDate);
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			
			If StructureData.TabName = "Products" Then
				StructureProductsData = GetDataProductsOnChange(StructureProductsData, StructureData.DocumentDate);
			Else
				StructureProductsData = GetDataProductsOnChange(StructureProductsData);
			EndIf;
			
			BarcodeData.Insert("StructureProductsData", StructureProductsData);
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit = StructureProductsData.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	If Items.Pages.CurrentPage = Items.PageProducts Then
		TableName = "Products";
	Else
		TableName = "Inventory";
	EndIf;
	
	StructureData = New Structure("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Counterparty", Object.Counterparty);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	StructureData.Insert("DocumentDate", Object.Date);
	StructureData.Insert("TabName", TableName);
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined And BarcodeData.Count() = 0 Then
			
			UnknownBarcodes.Add(CurBarcode);
			
		Else
			
			SearchStructure = New Structure;
			SearchStructure.Insert("Products", BarcodeData.Products);
			SearchStructure.Insert("Characteristic", BarcodeData.Characteristic);
			SearchStructure.Insert("MeasurementUnit", BarcodeData.MeasurementUnit);
			
			TSRowsArray = Object[TableName].FindRows(SearchStructure);
			If TSRowsArray.Count() = 0 Then
				
				NewRow = Object[TableName].Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = BarcodeData.MeasurementUnit;
				
			Else
				
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				
			EndIf;
			
			If TableName = "Products" Then
				ProductsRowCalculateAmount(NewRow);
			EndIf;
			
			Items[TableName].CurrentRow = NewRow.GetID();
			
			Modified = True;
		EndIf;
		
	EndDo;
	
	If TableName = "Products" And Modified Then
		RecalculateSubtotal();
	EndIf;
	
	Return UnknownBarcodes;
	
EndFunction

&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		NotifyDescription = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm("InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes),
			ThisObject,,,,
			NotifyDescription);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Barcode data is not found: %1; quantity: %2'; ru = '???????????? ???? ?????????????????? ???? ??????????????: %1; ????????????????????: %2';pl = 'Nie znaleziono danych kodu kreskowego: %1; ilo????: %2';es_ES = 'Datos del c??digo de barras no encontrados: %1; cantidad: %2';es_CO = 'Datos del c??digo de barras no encontrados: %1; cantidad: %2';tr = 'Barkod verisi bulunamad??: %1; miktar: %2';it = 'I dati del codice a barre non sono stati trovati: %1; quantit??: %2';de = 'Barcode-Daten wurden nicht gefunden: %1; Menge: %2'"),
			CurUndefinedBarcode.Barcode,
			CurUndefinedBarcode.Quantity);
		
		CommonClientServer.MessageToUser(MessageText);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CloseOrderEnd(Result, AdditionalParameters) Export
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);
	
	If Result = DialogReturnCode.Cancel Or Not Write(WriteParameters) Then
		Return;
	EndIf;
	
	CloseOrderFragment();
	
	FormManagement();
	
EndProcedure

&AtServer
Procedure CloseOrderFragment(Result = Undefined, AdditionalParameters = Undefined) Export
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.Ref);
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("SubcontractorOrdersIssued", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	
	Read();
	
	ResetStatus();
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	If GetAccessRightForDocumentPosting() Then
		Items.FormPost.Enabled			= (Not StatusIsComplete Or Not Object.Closed);
		Items.FormPostAndClose.Enabled	= (Not StatusIsComplete Or Not Object.Closed);
	EndIf;
	
	Items.FormWrite.Enabled				= (Not StatusIsComplete Or Not Object.Closed);
	Items.FormCreateBasedOn.Enabled		= (Not StatusIsComplete Or Not Object.Closed);
	Items.CloseOrder.Visible			= Not Object.Closed;
	Items.CloseOrder.Enabled			= DriveServer.CheckCloseOrderEnabled(Object.Ref);
	Items.ProductsCommandBar.Enabled	= Not StatusIsComplete;
	Items.InventoryCommandBar.Enabled	= Not StatusIsComplete;
	Items.ByProductsCommandBar.Enabled	= Not StatusIsComplete;
	Items.PricesAndCurrency.Enabled		= Not StatusIsComplete;
	Items.FillByBasis.Enabled			= Not StatusIsComplete;
	Items.Counterparty.ReadOnly			= StatusIsComplete;
	Items.Contract.ReadOnly				= StatusIsComplete;
	Items.GroupBasisDocument.ReadOnly	= StatusIsComplete;
	Items.ReceiptDate.ReadOnly			= StatusIsComplete;
	Items.RightColumn.ReadOnly			= StatusIsComplete;
	Items.Pages.ReadOnly				= StatusIsComplete;
	
	// begin Drive.FullVersion
	CommonClientServer.SetFormItemProperty(Items, "OrderReceived", "Visible", True);
	// end Drive.FullVersion
EndProcedure

&AtServerNoContext
Function GetAccessRightForDocumentPosting()
	
	Return AccessRight("Posting", Metadata.Documents.SubcontractorOrderIssued);
	
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	StructureData = GetDataDateOnChange(Object.Ref, Object.Date, Object.DocumentCurrency, SettlementsCurrency);
	
	AccountingPrice = StructureData.AccountingPrice;
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
	EndIf;
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Function GetDataDateOnChange(DocumentRef, DateNew, DocumentCurrency, SettlementsCurrency)
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	ProcessingCompanyVATNumbers();
	
	FillVATRateByCompanyVATTaxation();
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(DateNew, DocumentCurrency, Object.Company);
	
	StructureData = New Structure;
	StructureData.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	StructureData.Insert("AccountingPrice",
		InformationRegisters.AccountingPolicy.GetAccountingPolicy(DateNew, Object.Company).AccountingPrice);
	
	If DocumentCurrency <> SettlementsCurrency Then
		
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(DateNew, SettlementsCurrency, Object.Company);
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
		
	Else
		
		StructureData.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure SetAccountingPolicyValues()
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	PerInvoiceVATRoundingRule = AccountingPolicy.PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);
	
EndProcedure

&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsCounterpartyOnChange = False)
	
	If Not WorkWithVAT.VATTaxationTypeIsValid(Object.VATTaxation, RegisteredForVAT, False)
		Or Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT
		Or IsCounterpartyOnChange Then
		
		TaxationBeforeChange = Object.VATTaxation;
		
		Object.VATTaxation = DriveServer.CounterpartyVATTaxation(Object.Counterparty,
			DriveServer.VATTaxation(Object.Company, Object.Date),
			False);
		
		If Not TaxationBeforeChange = Object.VATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		Items.ProductsVATRate.Visible = True;
		Items.ProductsVATAmount.Visible = True;
		Items.ProductsTotal.Visible = True;
		Items.DocumentTax.Visible = True;
		
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Object.Date, Object.Company);
		
		For Each Row In Object.Products Do
			
			If ValueIsFilled(Row.Products.VATRate) Then
				Row.VATRate = Row.Products.VATRate;
			Else
				Row.VATRate = DefaultVATRate;
			EndIf;
			
			VATRate = DriveReUse.GetVATRateValue(Row.VATRate);
			
			Row.VATAmount = ?(Object.AmountIncludesVAT,
				Row.Amount - Row.Amount * 100 / (VATRate + 100),
				Row.Amount * VATRate / 100);
			Row.Total = Row.Amount + ?(Object.AmountIncludesVAT, 0, Row.VATAmount);
			
		EndDo;
		
	Else
		
		Items.ProductsVATRate.Visible = False;
		Items.ProductsVATAmount.Visible = False;
		Items.ProductsTotal.Visible = False;
		Items.DocumentTax.Visible = False;
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
		
		For Each Row In Object.Products Do
			
			Row.VATRate = DefaultVATRate;
			Row.VATAmount = 0;
			Row.Total = Row.Amount;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	CurRateRepetition = StructureData.CurrencyRateRepetition;
	SettlCurRateRepetition = StructureData.SettlementsCurrencyRateRepetition;
	
	NewExchangeRate = ?(CurRateRepetition.Rate = 0, 1, CurRateRepetition.Rate);
	NewRatio = ?(CurRateRepetition.Repetition = 0, 1, CurRateRepetition.Repetition);
	
	NewContractCurrencyExchangeRate = ?(SettlCurRateRepetition.Rate = 0, 1, SettlCurRateRepetition.Rate);
	NewContractCurrencyRatio = ?(SettlCurRateRepetition.Repetition = 0, 1, SettlCurRateRepetition.Repetition);
	
	If Object.ExchangeRate <> NewExchangeRate
		Or Object.Multiplicity <> NewRatio
		Or Object.ContractCurrencyExchangeRate <> NewContractCurrencyExchangeRate
		Or Object.ContractCurrencyMultiplicity <> NewContractCurrencyRatio Then
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate",					NewExchangeRate);
		QuestionParameters.Insert("NewRatio",							NewRatio);
		QuestionParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		QuestionParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("RecalculatePaymentCurrencyRateConversionFactorEnd",
			ThisObject, 
			QuestionParameters);
		
		MessageText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
		
		Return;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtClient
Procedure RecalculatePaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateLabelPricesAndCurrency(Form)
	
	Object = Form.Object;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("SettlementsCurrency",		Form.SettlementsCurrency);
	LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	LabelStructure.Insert("AmountIncludesVAT",			Object.AmountIncludesVAT);
	LabelStructure.Insert("ForeignExchangeAccounting",	Form.ForeignExchangeAccounting);
	LabelStructure.Insert("VATTaxation",				Object.VATTaxation);
	LabelStructure.Insert("RegisteredForVAT",			Form.RegisteredForVAT);
	
	Form.PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company);
	
EndFunction

&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.Contract, Object.Company);
			
		EndIf;
		
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		OpenFormPricesAndCurrencies = (ValueIsFilled(Object.Contract)
			And ValueIsFilled(SettlementsCurrency)
			And Object.DocumentCurrency <> ContractData.SettlementsCurrency
			And Object.Products.Count() > 0);
		
		DocumentParameters = New Structure;
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		
		ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataContractOnChange(Date, Contract, Company)
	
	StructureData = New Structure("SettlementsCurrency, SettlementsCurrencyRateRepetition, AmountIncludesVAT");
	
	If ValueIsFilled(Contract) Then
		AttributesValues = Common.ObjectAttributesValues(Contract, "SettlementsCurrency, SupplierPriceTypes");
		StructureData.SettlementsCurrency = AttributesValues.SettlementsCurrency;
		If ValueIsFilled(AttributesValues.SupplierPriceTypes) Then
			StructureData.AmountIncludesVAT = Common.ObjectAttributeValue(AttributesValues.SupplierPriceTypes, "PriceIncludesVAT");
		EndIf;
	Else
		StructureData.SettlementsCurrency = Catalogs.Currencies.EmptyRef();
		StructureData.AmountIncludesVAT = Undefined;
	EndIf;
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Date, StructureData.SettlementsCurrency, Company);
	StructureData.SettlementsCurrencyRateRepetition = CurrencyRateRepetition;
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	ContractData = DocumentParameters.ContractData;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	
	If ContractData.AmountIncludesVAT <> Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		
		CurrencyRateRepetition = ContractData.SettlementsCurrencyRateRepetition;
		
		Object.ExchangeRate = ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
		
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
		
	EndIf;
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, WarningText);
		
	Else
		
		GenerateLabelPricesAndCurrency(ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",					Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",					Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",				Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",					Object.Counterparty);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Company",						ParentCompany);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					False);
	ParametersStructure.Insert("RecalculatePrices",				RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("WarningText",					WarningText);
	ParametersStructure.Insert("AutomaticVATCalculation",		Object.AutomaticVATCalculation);
	ParametersStructure.Insert("PerInvoiceVATRoundingRule",		PerInvoiceVATRoundingRule);
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd",
		ThisObject,
		AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") AND ClosingResult.WereMadeChanges Then
		
		DocCurRecalcStructure = New Structure;
		DocCurRecalcStructure.Insert("DocumentCurrency", ClosingResult.DocumentCurrency);
		DocCurRecalcStructure.Insert("Rate", ClosingResult.ExchangeRate);
		DocCurRecalcStructure.Insert("Repetition", ClosingResult.Multiplicity);
		DocCurRecalcStructure.Insert("PrevDocumentCurrency", AdditionalParameters.DocumentCurrency);
		DocCurRecalcStructure.Insert("InitRate", AdditionalParameters.ExchangeRate);
		DocCurRecalcStructure.Insert("RepetitionBeg", AdditionalParameters.Multiplicity);
		
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.ExchangeRate;
		Object.Multiplicity = ClosingResult.Multiplicity;
		Object.ContractCurrencyExchangeRate = ClosingResult.SettlementsRate;
		Object.ContractCurrencyMultiplicity = ClosingResult.SettlementsMultiplicity;
		Object.VATTaxation = ClosingResult.VATTaxation;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.AutomaticVATCalculation = ClosingResult.AutomaticVATCalculation;
		
		// Recalculate prices by currency.
		If ClosingResult.RecalculatePrices Then
			DriveClient.RecalculateTabularSectionPricesByCurrency(ThisObject, DocCurRecalcStructure, "Products", PricesPrecision);
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If ClosingResult.AmountIncludesVAT <> ClosingResult.PrevAmountIncludesVAT Then
			DriveClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisObject, "Products", PricesPrecision);
		EndIf;
		
		Modified = True;
		RecalculateSubtotal();
		
	EndIf;
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtClient
Procedure RecalculateSubtotal()
	
	AmountTotal = Object.Products.Total("Total");
	VATAmountTotal = Object.Products.Total("VATAmount");
	
	Object.DocumentTax = VATAmountTotal;
	Object.DocumentSubtotal = AmountTotal - VATAmountTotal;
	Object.DocumentAmount = AmountTotal;
	
EndProcedure

&AtServer
Function GetCompanyDataOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Object.Company));
	
	AccountingDate = ?(ValueIsFilled(Object.Date), Object.Date, CurrentSessionDate());
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(
			AccountingDate,
			Object.Company);
	StructureData.Insert("AccountingPrice", AccountingPolicy.AccountingPrice);
	
	SetAccountingPolicyValues();
	SetAutomaticVATCalculation();
	
	ProcessingCompanyVATNumbers(False);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure SetAutomaticVATCalculation()
	
	Object.AutomaticVATCalculation = PerInvoiceVATRoundingRule;
	
EndProcedure

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val CatalogCounterparty)
	
	Attributes = "DoOperationsByContracts, VATTaxation";
	
	DriveServer.ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, Attributes);
	
EndProcedure

&AtServer
Function GetDataCounterpartyOnChange(Date, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company);
	
	StructureData = GetDataContractOnChange(Date, ContractByDefault, Company);
	StructureData.Insert("Contract", ContractByDefault);
	
	FillVATRateByCompanyVATTaxation(True);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure SetContractVisible()
	
	Items.Contract.Visible = CounterpartyAttributes.DoOperationsByContracts;
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.ProductsPrice);
	Fields.Add(Items.ByProductsCostValue);
	
	Return Fields;
	
EndFunction

&AtServerNoContext
Function GetChoiceFormOfContractParameters(Document, Company, Counterparty, Contract)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", True);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetSubcontractorOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SubcontractorOrderIssuedStatuses.Ref AS Status
	|FROM
	|	Catalog.SubcontractorOrderIssuedStatuses AS SubcontractorOrderIssuedStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON SubcontractorOrderIssuedStatuses.OrderStatus = OrderStatuses.Ref
	|
	|ORDER BY
	|	OrderStatuses.Order";
	
	Selection = Query.Execute().Select();
	ChoiceData = New ValueList;
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Status);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText,
	Document,
	Company,
	Counterparty,
	Contract,
	IsOperationsByContracts,
	Cancel)
	
	If Not DriveReUse.CounterpartyContractsControlNeeded() Or Not IsOperationsByContracts Then
		Return;
	EndIf;
	
	CatalogManager = Catalogs.CounterpartyContracts;
	
	ContractKindsList = CatalogManager.GetContractTypesListForDocument(Document);
	
	If Not CatalogManager.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		And Constants.CheckContractsOnPosting.Get() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ResetStatus()
	
	If Not GetFunctionalOption("UseSubcontractorOrderIssuedStatuses") Then
		
		OrderStatus = Common.ObjectAttributeValue(Object.OrderState, "OrderStatus");
		
		If OrderStatus = Enums.OrderStatuses.InProcess And Not Object.Closed Then
			Status = "StatusInProcess";
		ElsIf OrderStatus = Enums.OrderStatuses.Completed Then
			Status = "StatusCompleted";
		Else
			Status = "StatusCanceled";
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined)
	
	StuctureProduct = Common.ObjectAttributesValues(StructureData.Products,
		"MeasurementUnit, ProductsType, ReplenishmentMethod, VATRate");
	
	StructureData.Insert("ProductsType", StuctureProduct.ProductsType);
	StructureData.Insert("MeasurementUnit", StuctureProduct.MeasurementUnit);
	
	If StructureData.Property("VATTaxation") Then
		
		If StructureData.VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT Then
			
			If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
			Else
				StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
			EndIf;
			
		ElsIf ValueIsFilled(StuctureProduct.VATRate) Then
			StructureData.Insert("VATRate", StuctureProduct.VATRate);
		Else
			StructureData.Insert("VATRate",
				InformationRegisters.AccountingPolicy.GetDefaultVATRate(StructureData.ProcessingDate, StructureData.Company));
		EndIf;
		
	EndIf;
	
	StructureData.Insert("Price", 0);
	
	If ObjectDate <> Undefined Then
		
		If StructureData.Property("Characteristic") Then
			CharacteristicForBOM = StructureData.Characteristic;
		Else
			CharacteristicForBOM = Catalogs.ProductsCharacteristics.EmptyRef();
		EndIf;
		
		Specification = Documents.SubcontractorOrderIssued.GetAvailableBOM(StuctureProduct, ObjectDate, StructureData, CharacteristicForBOM);
		StructureData.Insert("Specification", Specification);
		
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate = Undefined)
	
	If ObjectDate <> Undefined Then
		
		BOM = Undefined;
		
		ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, "ReplenishmentMethod, ProductsType");
		
		BOM = Documents.SubcontractorOrderIssued.GetAvailableBOM(ProductsAttributes, ObjectDate, StructureData, StructureData.Characteristic);
		StructureData.Insert("Specification", BOM);

	EndIf;
	
	If StructureData.Property("PriceKind")
		And StructureData.Property("MeasurementUnit")
		And StructureData.MeasurementUnit = Undefined Then
		
		StructureData.Insert("Price", 0);
		
	ElsIf StructureData.Property("PriceKind") And StructureData.Property("MeasurementUnit") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
		
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			CurrentPagesProducts = (Items.Pages.CurrentPage = Items.PageProducts);
			
			TabularSectionName = "";
			If Items.Pages.CurrentPage = Items.PageProducts Then
				TabularSectionName = "Products";
			ElsIf Items.Pages.CurrentPage = Items.PageInventory Then
				TabularSectionName = "Inventory";
			ElsIf Items.Pages.CurrentPage = Items.PageByProducts Then
				TabularSectionName = "ByProducts";
			EndIf;
			
			If Not IsBlankString(TabularSectionName) Then
				
				Filter = New Structure;
				Filter.Insert("Products", ClosingResult.FilterProducts);
				
				RowsToDelete = Object[TabularSectionName].FindRows(Filter);
				For Each RowToDelete In RowsToDelete Do
					Object[TabularSectionName].Delete(RowToDelete);
				EndDo;
				
				GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If TabularSectionName = "Products" Then
			
			If ValueIsFilled(ImportRow.Products) Then
				
				NewRow.ProductsType = ImportRow.Products.ProductsType;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ByProductsRowCalculateTotal(Row = Undefined)
	
	If Row = Undefined Then
		Row = Items.ByProducts.CurrentData;
	EndIf;
	
	Row.Total = Row.Quantity * Row.CostValue;
	
EndProcedure

&AtClient
Procedure ProductsRowCalculateAmount(Row = Undefined)
	
	If Row = Undefined Then
		Row = Items.Products.CurrentData;
	EndIf;
	
	Row.Amount = Row.Quantity * Row.Price;
	
	CalculateVATAmount(Row);
	
	Row.Total = Row.Amount + ?(Object.AmountIncludesVAT, 0, Row.VATAmount);
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(Row)
	
	VATRate = DriveReUse.GetVATRateValue(Row.VATRate);
	
	If Object.AmountIncludesVAT Then
		Row.VATAmount = Row.Amount - Row.Amount / (VATRate + 100) * 100
	Else
		Row.VATAmount = Row.Amount * VATRate / 100;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			TabularSectionName = "";
			If Items.Pages.CurrentPage = Items.PageProducts Then
				TabularSectionName = "Products";
			ElsIf Items.Pages.CurrentPage = Items.PageInventory Then
				TabularSectionName = "Inventory";
			ElsIf Items.Pages.CurrentPage = Items.PageByProducts Then
				TabularSectionName = "ByProducts";
			EndIf;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByDocument(Attribute = "BasisDocument")
	
	Document = FormAttributeToValue("Object");
	Document.Fill(Object[Attribute]);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.PageAdditionalInformation, Object.Comment);
	
EndProcedure

&AtServer
Procedure FillByBillsOfMaterialsAtServer(IsByProducts = False)
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionBySpecification(IsByProducts);
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtClient
Procedure FillBySpecificationEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillBySpecificationFragment();
	
EndProcedure

&AtClient
Procedure FillBySpecificationByProductsEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillBySpecificationFragment(True);
	
EndProcedure

&AtClient
Procedure FillBySpecificationFragment(IsByProducts = False)
	
	FillByBillsOfMaterialsAtServer(IsByProducts);
	
	Modified = True;
	
	If IsByProducts Then
		
		HasEmptyPrice = False;
		For Each ByProductsLine In Object.ByProducts Do
			If ByProductsLine.CostValue = 0 Then
				HasEmptyPrice = True;
				Break;
			EndIf;
		EndDo;
		
		If HasEmptyPrice Then
			AccountingPriceMessage();
		EndIf;
	
	EndIf;
	
EndProcedure

&AtClient
Procedure FillBySpecificationTakingRelatedBOMsEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillBySpecificationTakingRelatedBOMsServer();
	
EndProcedure

&AtServer
Procedure FillBySpecificationTakingRelatedBOMsServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillInventoryWithBOMTakingRelatedBOMs();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtClient
Function CheckBOMFilling()
	
	Result = True;
	
	MessageTemplate = NStr("en = 'Bill of materials is required on line %1'; ru = '?? ???????????? %1 ?????????????????? ????????????????????????';pl = 'Specyfikacja materia??owa jest wymagana w wierszu %1';es_ES = 'Se requiere una lista de materiales en l??nea%1';es_CO = 'Se requiere una lista de materiales en l??nea%1';tr = '%1 sat??r??nda ??r??n re??etesi zorunlu';it = 'La distinta base ?? richiesta nella riga %1';de = 'St??ckliste ist in der Zeile %1 erforderlich'");
	
	For Each ProductsRow In Object.Products Do
		
		If Not ValueIsFilled(ProductsRow.Specification) Then
			
			Result = False;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate,
				ProductsRow.LineNumber);
			
			CommonClientServer.MessageToUser(
				MessageText,
				,
				CommonClientServer.PathToTabularSection("Object.Products", ProductsRow.LineNumber, "Specification"));
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure AccountingPriceMessage()
	CommonClientServer.MessageToUser(NStr("en = 'The price is required for the by-product. Fill in the Accounting price in
		| the Accounting policy or specify the price on the by-product card.'; 
		|ru = '?????? ???????????????? ?????????????????? ???????????????????? ?????????????? ????????. ?????????????????? ?????????????? ???????? ??
		| ?????????????? ???????????????? ?????? ?????????????? ???????? ?? ???????????????? ???????????????? ??????????????????.';
		|pl = 'Wymagana jest cena produktu ubocznego. Wype??nij Cen?? ewidencyjn?? w
		| Polityce rachunkowo??ci lub okre??l cen?? na karcie Produkty uboczne.';
		|es_ES = 'Se requiere el precio del trozo y deterioro. Rellene el Precio contable en
		| la Pol??tica de Contabilidad o especifique el precio en la tarjeta del trozo y deterioro.';
		|es_CO = 'Se requiere el precio del trozo y deterioro. Rellene el Precio contable en
		| la Pol??tica de Contabilidad o especifique el precio en la tarjeta del trozo y deterioro.';
		|tr = 'Yan ??r??n i??in fiyat gerekli. Muhasebe politikas??nda
		| muhasebe fiyat??n?? doldurun veya yan ??r??n kart??nda fiyat?? girin.';
		|it = 'Il prezzo ?? richiesto per il sottoprodotto. Compilare il Prezzo contabile nella
		| Politica contabile o indicare il prezzo sulla scheda del sottoprodotto.';
		|de = 'Der Preis ist f??r das Nebenprodukt erforderlich. Geben Sie den Abrechnungspreis in
		|den Bilanzierungsrichtlinien ein oder geben Sie den Preis auf der Nebenproduktkarte an.'"));
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSource

&AtClient
Procedure LoadFromFileByProducts(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.SubcontractorOrderIssued.TabularSection.ByProducts";
	
	DataLoadSettings.Insert("TabularSectionFullName", "SubcontractorOrderIssued.ByProducts");
	DataLoadSettings.Insert("Title", NStr("en = 'Import by-products from file'; ru = '?????????????????? ???????????????? ?????????????????? ???? ??????????';pl = 'Importuj produkty uboczne z pliku';es_ES = 'Importar los subproductos del archivo';es_CO = 'Importar los subproductos del archivo';tr = 'Yan ??r??nleri dosyadan i??e aktar';it = 'Importare scarti e residui da file';de = 'Nebenprodukte aus Datei importieren'"));
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure LoadFromFileInventory(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.SubcontractorOrderIssued.TabularSection.Inventory";
	
	DataLoadSettings.Insert("TabularSectionFullName", "SubcontractorOrderIssued.Inventory");
	DataLoadSettings.Insert("Title", NStr("en = 'Import inventory from file'; ru = '???????????????? ?????????????? ???? ??????????';pl = 'Import zapas??w z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan i??e aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		ProcessPreparedData(ImportResult);
		
		RecalculateSubtotal();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

// End StandardSubsystems.DataImportFromExternalSource

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

// End StandardSubsystems.AttachableCommand

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

#EndRegion

#EndRegion