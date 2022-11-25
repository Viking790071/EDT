
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("BaselineDate") Then
		BaselineDate = Parameters.BaselineDate;
	EndIf;
		
	FillPropertyValues(Object, Parameters);
	Object.StagesOfPayment.Clear();
	
	FillStagesOfPaymentFromTempStorage(Parameters.AddressInTempStorage);
	
	CalculateTotalPaymentTerms(ThisForm);
	SetDecorationExampleTitle();
	
	SetEarlyPaymentDiscountsVisible();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetDirectDebitMandateVisible();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	StandardProcessing = False;
	
	If CloseFormWithoutConfirmation Then
		Return;
	EndIf;
	
	If Modified AND Not Exit Then
		
		Cancel = True;
		ShowQueryBox(
			New NotifyDescription("BeforeCloseEnd", ThisObject),
			NStr("en = 'All changes will be lost. Continue?'; ru = 'Все измененные данные будут потеряны. Продолжить?';pl = 'Wszystkie zmiany zostaną utracone. Kontynuować?';es_ES = 'Todos los cambios se perderán. ¿Continuar?';es_CO = 'Todos los cambios se perderán. ¿Continuar?';tr = 'Tüm değişikler kaybolacak. Devam et?';it = 'Tutte le modifiche andranno perse. Continuare?';de = 'Alle Änderungen gehen verloren. Fortsetzen?'"),
			QuestionDialogMode.OKCancel);
			
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		CloseFormWithoutConfirmation = True;
		Close();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetConditionalAppearance();
	CalculateTotalPaymentTerms(ThisForm);
	SetDecorationExampleTitle();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PaymentMethodOnChange(Item)
	
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	
	SetDirectDebitMandateVisible();
	
EndProcedure

&AtClient
Procedure PaymentTermsTemplateOnChange(Item)
	
	FillFormByPaymentTermsTemplate();
	
	CalculateTotalPaymentTerms(ThisForm);
	SetDecorationExampleTitle();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersStagesOfPayment

&AtClient
Procedure StagesOfPaymentOnEditEnd(Item, NewRow, CancelEdit)
	CalculateTotalPaymentTerms(ThisForm);
EndProcedure

&AtClient
Procedure StagesOfPaymentAfterDeleteRow(Item)
	CalculateTotalPaymentTerms(ThisForm);
	SetDecorationExampleTitle();
EndProcedure

&AtClient
Procedure StagesOfPaymentTermOnChange(Item)
	SetDecorationExampleTitle();
EndProcedure

&AtClient
Procedure StagesOfPaymentDuePeriodOnChange(Item)
	SetDecorationExampleTitle();
EndProcedure

&AtClient
Procedure StagesOfPaymentBaselineDateOnChange(Item)
	
	CurrentData = Items.StagesOfPayment.CurrentData;
	CurrentData.Term = GetPaymentTermByBaselineDate(CurrentData.BaselineDate);
	
	SetDecorationExampleTitle();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	
	If Not Modified Then
		Close();
	ElsIf StagesOfPaymentIsCorrect() AND CheckEarlyPaymentDiscounts() AND CheckRequiredFilling() Then
		
		ObjectStructure = New Structure();
		ObjectStructure.Insert("PaymentMethod", Object.PaymentMethod);
		ObjectStructure.Insert("CashAssetType", Object.CashAssetType);
		ObjectStructure.Insert("ProvideEPD", Object.ProvideEPD);
		ObjectStructure.Insert("PaymentTermsTemplate", Object.PaymentTermsTemplate);
		ObjectStructure.Insert("AddressInTempStorage", PutToTempStorageAtServer());
		ObjectStructure.Insert("DirectDebitMandate", Object.DirectDebitMandate);
		
		CloseFormWithoutConfirmation = True;
		Close(ObjectStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	CloseFormWithoutConfirmation = True;
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	FieldsOfItem = Item.Fields.Items.Add();
	FieldsOfItem.Field = New DataCompositionField(Items.StagesOfPaymentPercentageOfPayment.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.StagesOfPayment.IncorrectPersentageOfPayment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	FieldsOfItem = Item.Fields.Items.Add();
	FieldsOfItem.Field = New DataCompositionField(Items.StagesOfPaymentPercentageOfPayment.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.StagesOfPayment.IncorrectPersentageOfPayment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.StagesOfPayment.LineNumber");
	ItemFilter.ComparisonType = DataCompositionComparisonType.LessOrEqual;
	ItemFilter.RightValue = New DataCompositionField("LineNumberOfTheTotalPayment");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("LineNumberOfTheTotalPayment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.SuccessResultColor);
	
EndProcedure

&AtServer
Function StagesOfPaymentIsCorrect()
	
	Return Catalogs.PaymentTermsTemplates.CheckStagesOfPayment(Object);
	
EndFunction

&AtServer
Function PutToTempStorageAtServer()
	
	StructureForTables = New Structure;
	StructureForTables.Insert("StagesOfPayment", Object.StagesOfPayment.Unload());
	StructureForTables.Insert("EarlyPaymentDiscounts", Object.EarlyPaymentDiscounts.Unload());
	
	Return PutToTempStorage(StructureForTables, UUID);
	
EndFunction

&AtClientAtServerNoContext
Procedure CalculateTotalPaymentTerms(Form)
	
	PaymentPercentageTotal = 0;
	PreviousDuePeriod = 0;
	Form.LineNumberOfTheTotalPayment = 0;
	IsIncorrectPersentageOfPayment = (Form.Object.StagesOfPayment.Total("PaymentPercentage") <> 100);
	
	For Each CurrentRow In Form.Object.StagesOfPayment Do
		
		PaymentPercentageTotal = PaymentPercentageTotal + CurrentRow.PaymentPercentage;
		CurrentRow.IncorrectPersentageOfPayment = IsIncorrectPersentageOfPayment;
		If PaymentPercentageTotal = 100 Then 
			Form.LineNumberOfTheTotalPayment = CurrentRow.LineNumber;
		EndIf;
		
		PreviousDuePeriod = CurrentRow.DuePeriod;
		
	EndDo;
	
EndProcedure

&AtServer
Function CheckEarlyPaymentDiscounts()
	
	Return EarlyPaymentDiscountsServer.CheckEarlyPaymentDiscounts(Object.EarlyPaymentDiscounts, Object.ProvideEPD);
	
EndFunction

&AtClient 
Function CheckRequiredFilling()
	
	Cancel = False;
	
	If Not ValueIsFilled(Object.PaymentMethod) Then
		ErrorText = NStr("en = 'Payment method is required.'; ru = 'Укажите способ оплаты.';pl = 'Wymagana jest metoda płatności.';es_ES = 'Se requiere una forma de pago.';es_CO = 'Se requiere una forma de pago.';tr = 'Ödeme yöntemi gerekli.';it = 'È richiesto il metodo di pagamento.';de = 'Zahlungsmethode ist ein Pflichtfeld.'");
		CommonClientServer.MessageToUser(ErrorText, , "Object.PaymentMethod", , Cancel);
	EndIf;
	
	Return Not Cancel;
	
EndFunction	
	
&AtServer
Procedure SetEarlyPaymentDiscountsVisible()
	
	VisibleFlag = (Object.ContractKind = Enums.ContractType.WithCustomer
		OR Object.ContractKind = Enums.ContractType.WithVendor);
	
	Items.EarlyPaymentDiscountsGroup.Visible = VisibleFlag;
	
EndProcedure

&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

&AtServer
Procedure FillFormByPaymentTermsTemplate()

	If Not ValueIsFilled(Object.PaymentTermsTemplate) Then
		Return;
	EndIf;
	
	Template = Object.PaymentTermsTemplate;
	
	Object.PaymentMethod = Template.PaymentMethod;
	Object.ProvideEPD = Template.ProvideEPD;
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	
	Object.StagesOfPayment.Clear();
	For Each Row In Template.StagesOfPayment Do
		NewRow = Object.StagesOfPayment.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	
	Object.EarlyPaymentDiscounts.Clear();
	For Each Row In Template.EarlyPaymentDiscounts Do
		NewRow = Object.EarlyPaymentDiscounts.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;

EndProcedure

&AtServer
Procedure SetDecorationExampleTitle()
	PaymentTermsServer.SetDecorationExampleTitle(Object.StagesOfPayment, Items.DecorationExample);
EndProcedure

&AtServerNoContext
Function GetPaymentTermByBaselineDate(BaselineDate)
	Return PaymentTermsServer.GetPaymentTermByBaselineDate(BaselineDate);	
EndFunction

&AtClient
Procedure SetDirectDebitMandateVisible()
	If Object.PaymentMethod = PredefinedValue("Catalog.PaymentMethods.DirectDebit") Then
		Items.DirectDebitMandate.Visible = True;
	Else
		Items.DirectDebitMandate.Visible = False;
		Object.DirectDebitMandate = Undefined;
	EndIf;
EndProcedure

&AtServer
Procedure FillStagesOfPaymentFromTempStorage(TempStorage)
	
	StructureForTables = GetFromTempStorage(TempStorage);
	
	Object.StagesOfPayment.Load(StructureForTables.StagesOfPayment);
	Object.EarlyPaymentDiscounts.Load(StructureForTables.EarlyPaymentDiscounts);
	
EndProcedure

#EndRegion
