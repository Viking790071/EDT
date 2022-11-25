
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
	SetConditionalAppearance();
	CalculateTotalPaymentTerms(ThisForm);
	SetDecorationExampleTitle();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ClearMessages();
	CheckStagesOfPaymentAndEarlyPaymentDiscounts(Cancel);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
	SetConditionalAppearance();
	CalculateTotalPaymentTerms(ThisForm);
	SetDecorationExampleTitle();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

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
Procedure StagesOfPaymentBaselineDateOnChange(Item)
	
	CurrentData = Items.StagesOfPayment.CurrentData;
	CurrentData.Term = GetPaymentTermByBaselineDate(CurrentData.BaselineDate);
	
	SetDecorationExampleTitle();
	
EndProcedure

&AtClient
Procedure StagesOfPaymentDuePeriodOnChange(Item)
	SetDecorationExampleTitle();
EndProcedure

#EndRegion 

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	FieldsOfItem = Item.Fields.Items.Add();
	FieldsOfItem.Field = New DataCompositionField(Items.StagesOfPaymentPaymentPercentage.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.StagesOfPayment.IncorrectPersentageOfPayment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	FieldsOfItem = Item.Fields.Items.Add();
	FieldsOfItem.Field = New DataCompositionField(Items.StagesOfPaymentPaymentPercentage.Name);
	
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
Procedure CheckStagesOfPaymentAndEarlyPaymentDiscounts(Cancel)

	StagesOfPaymentAreCorrect = Catalogs.PaymentTermsTemplates.CheckStagesOfPayment(Object);
	EarlyPaymentDiscountsAreCorrect = EarlyPaymentDiscountsServer.CheckEarlyPaymentDiscounts(Object.EarlyPaymentDiscounts, Object.ProvideEPD);
	
	If StagesOfPaymentAreCorrect And EarlyPaymentDiscountsAreCorrect Then
		Return;
	EndIf;
	
	Cancel = True;

EndProcedure

&AtServer
Procedure SetDecorationExampleTitle()
	PaymentTermsServer.SetDecorationExampleTitle(Object.StagesOfPayment, Items.DecorationExample);
EndProcedure

&AtServerNoContext
Function GetPaymentTermByBaselineDate(BaselineDate)
	
	If BaselineDate = Enums.BaselineDateForPayment.DocumentDate 
		Or BaselineDate = Enums.BaselineDateForPayment.PostingDate Then
		
		Return Enums.PaymentTerm.PaymentInAdvance;
	Else
		Return Enums.PaymentTerm.Net;
	EndIf;
	
EndFunction

#EndRegion
