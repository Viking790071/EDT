
#Region FormEventHandlers

// Procedure - handler of the WhenCreatingOnServer event of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Predefined values
	LoanKindReceivedCredit = PredefinedValue("Enum.LoanContractTypes.Borrowed");
	// End Predefined values
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	WorkWithFilters.RestoreFilterSettings(ThisObject, List);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnClose(Exit = False)
	
	If Not Exit Then
		SaveFilterSettings();
	EndIf; 

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCounterpartyChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetMarkAndListFilter("Counterparty", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterLoanKindChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetMarkAndListFilter("LoanKind", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterEmployeeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetMarkAndListFilter("Employee", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterCompanyChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetMarkAndListFilter("Company", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenReportOnCredits(Command)
	
	OpenParameters = New Structure("VariantKey, GenerateOnOpening, Uniqueness", "LoansReceived", True);
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined AND CurrentData.LoanKind = LoanKindReceivedCredit Then
		OpenParameters.Insert("Filter", New Structure("Counterparty", CurrentData.Counterparty));
	EndIf;
	
	OpenForm("Report.LoanAccountStatement.Form", OpenParameters);
	
EndProcedure

&AtClient
Procedure OpenLoanReport(Command)
	
	OpenParameters = New Structure("VariantKey, GenerateOnOpening, Uniqueness", "LoansToEmployees", True);
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined AND CurrentData.LoanKind <> LoanKindReceivedCredit Then
		
		If CurrentData.LoanKind = PredefinedValue("Enum.LoanContractTypes.CounterpartyLoanAgreement") Then
			CurrentDataBorrower = CurrentData.Counterparty;
		Else 
			CurrentDataBorrower = CurrentData.Employee;
		EndIf;
		OpenParameters.Insert("Filter", New Structure("Borrower", CurrentDataBorrower));
		
	EndIf;
	
	OpenForm("Report.LoanAccountStatement.Form", OpenParameters);
	
EndProcedure

#EndRegion

#Region Private

#Region FilterMarks

&AtServer
Procedure SetMarkAndListFilter(FilterFieldListName, GroupMarkParent, SelectedValue, ValuePresentation="")
	
	If ValuePresentation = "" Then
		ValuePresentation = String(SelectedValue);
	EndIf; 
	
	WorkWithFilters.AttachFilterLabel(ThisObject, FilterFieldListName, GroupMarkParent, SelectedValue, ValuePresentation);
	WorkWithFilters.SetListFilter(ThisObject, List, FilterFieldListName);
	
EndProcedure

&AtClient
Procedure Attachable_LabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	IDMark = Mid(Item.Name, StrLen("Label_") + 1);
	DeleteFilterMark(IDMark);
	
EndProcedure

&AtServer
Procedure DeleteFilterMark(IDMark)
	
	WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, IDMark);

EndProcedure

&AtClient
Procedure PeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithFiltersClient.PeriodPresentationSelectPeriod(ThisObject, "List", "Date");
	
EndProcedure

&AtServer
Procedure SaveFilterSettings()
	
	WorkWithFilters.SaveFilterSettings(ThisObject);
	
EndProcedure

&AtClient
Procedure CollapseExpandFilterBar(Item)
	
	NewValueVisibility = Not Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisibility);
		
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion
