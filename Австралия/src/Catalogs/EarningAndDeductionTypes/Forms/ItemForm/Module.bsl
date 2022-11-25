
#Region FormEventHandlers

// Event handler procedure
// OnCreateAtServer Performs initial form attribute filling.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Tax			= Enums.EarningAndDeductionTypes.Tax;
	Deduction	= Enums.EarningAndDeductionTypes.Deduction;
	
	If Not Constants.UsePersonalIncomeTaxCalculation.Get() Then
		
		ItemOfList = Items.Type.ChoiceList.FindByValue(Tax);
		If ItemOfList <> Undefined Then
			
			Items.Type.ChoiceList.Delete(ItemOfList);
			
		EndIf;
		
	EndIf; 
	
	IsTax = (Object.Type = Tax);
	CommonClientServer.SetFormItemProperty(Items, "TaxKind", "Visible", IsTax);
	CommonClientServer.SetFormItemProperty(Items, "GroupFormula", "Visible", Not IsTax);
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") And Not ValueIsFilled(Object.GLExpenseAccount) Then
		OnChangeEarningKindTypelAtServer(Object.Type);
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetVisibleAndEnabled();
EndProcedure

// Event handler procedure NotificationProcessing
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AccountsChangedEarningAndDeductionTypes" Then
		
		Object.GLExpenseAccount = Parameter.GLExpenseAccount;
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
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

// Event handler procedure OnChange of input field LegalEntityIndividual.
//
&AtClient
Procedure TypeOnChange(Item)
	
	SetVisibleAndEnabled();
	OnChangeEarningKindTypelAtServer(Object.Type);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Procedure is called when clicking the "Edit calculation formula" buttons. 
//
&AtClient
Procedure CommandEditCalculationFormula(Command)
	
	ParametersStructure = New Structure("FormulaText", Object.Formula);
	Notification = New NotifyDescription("CommandEditFormulaOfCalculationEnd",ThisForm);
	OpenForm("Catalog.EarningAndDeductionTypes.Form.CalculationFormulaEditForm", ParametersStructure,,,,, Notification);
	
EndProcedure

&AtClient
Procedure CommandEditFormulaOfCalculationEnd(FormulaText,Parameters) Export

	If TypeOf(FormulaText) = Type("String") Then
		Object.Formula = FormulaText;
	EndIf;

EndProcedure

#EndRegion

#Region Private

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtClient
Procedure SetVisibleAndEnabled()
	
	If Object.Type = Tax Then
		
		Object.GLExpenseAccount		= Undefined;
		Items.GroupFormula.Visible	= False;
		Object.Formula				= "";
		Items.TaxKind.Visible		= True;
		
	Else
		
		Items.GroupFormula.Visible	= True;
		Items.TaxKind.Visible		= False;
		Object.TaxKind				= Undefined;
		
	EndIf;
	
EndProcedure

// Procedure sets the values dependending on the type selected
//
&AtServer
Procedure OnChangeEarningKindTypelAtServer(EarningKindType)
	
	If EarningKindType = Deduction Then
		Object.GLExpenseAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollExpenses");
	Else	
		Object.GLExpenseAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses");
	EndIf;
	
EndProcedure

#EndRegion
