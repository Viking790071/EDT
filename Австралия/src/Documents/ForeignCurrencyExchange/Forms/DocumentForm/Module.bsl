
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PresentationCurrency = GetPresentationCurrency(Object.Company);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	KeyDataOnChange(False);
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	CashExchange = Object.CashExchange;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetAccountsTypeRestriction();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
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
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	
	PresentationCurrency = GetPresentationCurrency(Object.Company);
	
EndProcedure

&AtClient
Procedure FromAccountOnChange(Item)
	FromAccountOnChangeAtServer();
EndProcedure

&AtClient
Procedure ToAccountOnChange(Item)
	ToAccountOnChangeAtServer();
EndProcedure

&AtClient
Procedure ToAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Object.FromAccount) Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ExcludeCurrency", Object.FromAccountCurrency);
		
		StandardProcessing = False;
		
		If Object.CashExchange Then
			OpenForm("Catalog.CashAccounts.ChoiceForm", FormParameters, Item);
		Else
			FormParameters.Insert("Owner", Object.Company);
			OpenForm("Catalog.BankAccounts.ChoiceForm", FormParameters, Item);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BankChargeOnChange(Item)
	BankChargeOnChangeAtServer();
EndProcedure

&AtClient
Procedure BankFeeValueOnChange(Item)
	CalculateData();
EndProcedure

&AtClient
Procedure DocumentAmountOnChange(Item)
	CalculateData();
EndProcedure

&AtClient
Procedure FromAccountExchangeRateOnChange(Item)
	
	CalculateData();
	
EndProcedure

&AtClient
Procedure FromAccountMultiplicityOnChange(Item)
	
	CalculateData();
	
EndProcedure

&AtClient
Procedure ToAccountExchangeRateOnChange(Item)
	
	CalculateData();
	
EndProcedure

&AtClient
Procedure ToAccountMultiplicityOnChange(Item)
	
	CalculateData();
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CashExchangeOnChange(Item)
	
	Object.CashExchange = CashExchange;
	
	SetCashExchangeAttribute();
	
EndProcedure

&AtClient
Procedure TotalReceivingCurrencyHeaderOnChange(Item)
	
	Object.ManualTotalReceivingCurrency = True;
	Object.TotalReceivingCurrency = TotalReceivingCurrency;
	
	CalculateData(False);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetPresentationCurrency(Company)
	
	Return DriveServer.GetPresentationCurrency(Company);
	
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	KeyDataOnChange();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure ToAccountOnChangeAtServer()
	
	If Object.CashExchange Then
		Object.ToAccountCurrency = Common.ObjectAttributeValue(Object.ToAccount, "CurrencyByDefault");
	Else
		Object.ToAccountCurrency = Common.ObjectAttributeValue(Object.ToAccount, "CashCurrency");
	EndIf;
	
	KeyDataOnChange();
	
EndProcedure

&AtServer
Procedure FromAccountOnChangeAtServer()
	
	If Object.CashExchange Then
		Object.FromAccountCurrency = Common.ObjectAttributeValue(Object.FromAccount, "CurrencyByDefault");
	Else
		Object.FromAccountCurrency = Common.ObjectAttributeValue(Object.FromAccount, "CashCurrency");
	EndIf;
	
	KeyDataOnChange();
	
EndProcedure
 
&AtServer
Procedure BankChargeOnChangeAtServer()
	
	StructureBankCharge = Common.ObjectAttributesValues(Object.BankCharge, "Item, Value, ExpenseItem");
	
	Object.BankChargeItem = StructureBankCharge.Item;
	Object.BankFeeValue = StructureBankCharge.Value;
	Object.ExpenseItem = StructureBankCharge.ExpenseItem;
	
	KeyDataOnChange();
	
EndProcedure

&AtServer
Procedure SetVisibilityItems()
	
	BankChargeType = Common.ObjectAttributeValue(Object.BankCharge, "ChargeType");
	SpecialExchangeRate = (BankChargeType = Enums.ChargeMethod.SpecialExchangeRate);
	
	SendingExchangeRateIsVisible	= ValueIsFilled(Object.FromAccount) AND (Object.FromAccountCurrency <> PresentationCurrency);
	ReceivingExchangeRateIsVisible	= ValueIsFilled(Object.ToAccount) AND (Object.ToAccountCurrency <> PresentationCurrency);
	
	Items.BankFeeValue.Visible	= NOT SpecialExchangeRate;
	Items.FeeGroup.Visible		= NOT BankChargeType = Enums.ChargeMethod.Amount AND PresentationCurrency <> Object.FromAccountCurrency;
	
	Items.FromAccountExchangeRateGroup.Visible				= SendingExchangeRateIsVisible AND SpecialExchangeRate;
	Items.FromAccountCentralBankExchangeRateGroup.Visible	= SendingExchangeRateIsVisible;
	
	Items.ToAccountExchangeRateGroup.Visible			= ReceivingExchangeRateIsVisible AND SpecialExchangeRate;
	Items.ToAccountCentralBankExchangeRateGroup.Visible	= ReceivingExchangeRateIsVisible;
	
	IsChargeMethodPercent = (BankChargeType = Enums.ChargeMethod.Percent);
	
	Items.AmountCurrency.Visible	= Not IsChargeMethodPercent;
	Items.DecorationPercent.Visible	= IsChargeMethodPercent;
	
EndProcedure

&AtServer
Procedure CalculateData(ResetManualTotalReceivingCurrency = True)
	
	If NOT (ValueIsFilled(Object.BankCharge)
		AND ValueIsFilled(Object.ToAccount)
		AND ValueIsFilled(Object.FromAccount)
		AND ValueIsFilled(Object.DocumentAmount)) Then
		Return;
	EndIf;
	
	If PresentationCurrency = Object.FromAccountCurrency Then
		Object.FromAccountExchangeRate = 1;
		Object.FromAccountMultiplicity = 1;
	EndIf;
	
	If PresentationCurrency = Object.ToAccountCurrency Then
		Object.ToAccountExchangeRate = 1;
		Object.ToAccountMultiplicity = 1;
	EndIf;
	
	If Object.FromAccountExchangeRate = 0 Then
		Object.FromAccountExchangeRate = 1;
	EndIf;
	
	If Object.FromAccountMultiplicity = 0 Then
		Object.FromAccountMultiplicity = 1;
	EndIf;
	
	If Object.ToAccountExchangeRate = 0 Then
		Object.ToAccountExchangeRate = 1;
	EndIf;
	
	If Object.ToAccountMultiplicity = 0 Then
		Object.ToAccountMultiplicity = 1;
	EndIf;
	
	If ResetManualTotalReceivingCurrency Then
		Object.ManualTotalReceivingCurrency = False;
	EndIf;
	
	CalculatedData = Documents.ForeignCurrencyExchange.GetCalculatedData(Object);
	
	FillPropertyValues(ThisObject, CalculatedData);
	
EndProcedure

&AtServer
Procedure KeyDataOnChange(ResetManualTotalReceivingCurrency = True)
	
	If ValueIsFilled(Object.ToAccount)
		AND ValueIsFilled(Object.ToAccountCurrency)
		AND Object.ToAccountCurrency = Object.FromAccountCurrency Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Please, select accounts of different currencies'; ru = 'Укажите счета с разными валютами';pl = 'Proszę wybrać konta w różnych walutach';es_ES = 'Por favor, seleccione las cuentas de las monedas diferentes';es_CO = 'Por favor, seleccione las cuentas de las monedas diferentes';tr = 'Lütfen farklı para birimlerinde olan hesapları seçin';it = 'Per piacere, selezionare conti di valute differenti';de = 'Bitte wählen Sie Konten in verschiedenen Währungen aus.'"),,
			"ToAccount",
			"Object");
	EndIf;
	
	AmountTitlePattern = NStr("en = 'Amount %1'; ru = 'Сумма %1';pl = 'Wartość %1';es_ES = 'Cantidad %1';es_CO = 'Cantidad %1';tr = 'Tutar %1';it = 'Importo %1';de = 'Betrag %1'");
	
	Items.SendingAmout.Title = StringFunctionsClientServer.SubstituteParametersToString(
								AmountTitlePattern,
								"(" + Object.FromAccountCurrency + ")");
								
	Items.SendingAmoutCurrency.Title = StringFunctionsClientServer.SubstituteParametersToString(
									AmountTitlePattern,
									"(" + PresentationCurrency + ")");

	Items.ReceivingAmountCurrency.Title = StringFunctionsClientServer.SubstituteParametersToString(
									AmountTitlePattern,
									"(" + Object.ToAccountCurrency + ")");
									
	Items.ReceivingAmount.Title = Items.SendingAmoutCurrency.Title;
	
	CalculateData(ResetManualTotalReceivingCurrency);
	SetVisibilityItems();

EndProcedure

&AtClient
Procedure SetCashExchangeAttribute()
	
	SetAccountsTypeRestriction();
	
	Object.FromAccount = Items.FromAccount.TypeRestriction.AdjustValue(Object.FromAccount);
	Object.ToAccount = Items.ToAccount.TypeRestriction.AdjustValue(Object.ToAccount);
	
	FromAccountOnChangeAtServer();
	ToAccountOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure SetAccountsTypeRestriction()
	
	ArrayOfTypes = New Array;
	
	If Object.CashExchange Then
		
		ArrayOfTypes.Add(Type("CatalogRef.CashAccounts"));
		
	Else
		
		ArrayOfTypes.Add(Type("CatalogRef.BankAccounts"));
		
	EndIf;
	
	TypeDescription = New TypeDescription(ArrayOfTypes);
	
	Items.FromAccount.TypeRestriction = TypeDescription;
	Items.ToAccount.TypeRestriction = TypeDescription;
	
EndProcedure


#Region LibrariesHandlers

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.Additionally, Object.Comment);
	
EndProcedure

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

#EndRegion

#EndRegion
