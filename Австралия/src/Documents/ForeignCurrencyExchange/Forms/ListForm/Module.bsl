
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillCompaniesList();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	FixedArrayCompanies = New FixedArray(CompaniesList.UnloadValues());
	NewParameter = New ChoiceParameter("Filter.Owner", FixedArrayCompanies);
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	Items.FilterFromAccount.ChoiceParameters = NewParameters;
	Items.FilterToAccount.ChoiceParameters = NewParameters;
	
EndProcedure

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	If ValueIsFilled(FilterCompany) Then
	
		NewParameter = New ChoiceParameter("Filter.Owner", FilterCompany);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.FilterFromAccount.ChoiceParameters = NewParameters;
		Items.FilterToAccount.ChoiceParameters = NewParameters;
	
	Else
	
		FixedArrayCompanies = New FixedArray(CompaniesList.UnloadValues());
		NewParameter = New ChoiceParameter("Filter.Owner", FixedArrayCompanies);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.FilterFromAccount.ChoiceParameters = NewParameters;
		Items.FilterToAccount.ChoiceParameters = NewParameters;
	
	EndIf; 
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
Procedure FilterFromAccountOnChange(Item)
	
	SetCompanyFromAccount(FilterFromAccount);
	DriveClientServer.SetListFilterItem(List, "FromAccount", FilterFromAccount, ValueIsFilled(FilterFromAccount));
	
EndProcedure

&AtClient
Procedure FilterToAccountOnChange(Item)
	
	SetCompanyFromAccount(FilterToAccount);
	DriveClientServer.SetListFilterItem(List, "ToAccount", FilterToAccount, ValueIsFilled(FilterToAccount));
	
EndProcedure

&AtClient
Procedure FilterFromAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenSelectAccountForm(Item);
	
EndProcedure

&AtClient
Procedure FilterFromAccountChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("Structure") Then
		
		FilterFromAccount = SelectedValue.Catalog;
		
		SetCompanyFromAccount(FilterFromAccount);
		
		DriveClientServer.SetListFilterItem(List, "FromAccount", FilterFromAccount, ValueIsFilled(FilterFromAccount));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterToAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenSelectAccountForm(Item);
	
EndProcedure

&AtClient
Procedure FilterToAccountChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("Structure") Then
		
		FilterToAccount = SelectedValue.Catalog;
		
		SetCompanyFromAccount(FilterToAccount);
		
		DriveClientServer.SetListFilterItem(List, "ToAccount", FilterToAccount, ValueIsFilled(FilterToAccount));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetCompanyFromAccount(Account)
	
	If TypeOf(Account) = Type("CatalogRef.BankAccounts") Then
		FilterCompany = GetCompany(Account);
	Else
		FilterCompany = PredefinedValue("Catalog.Companies.EmptyRef");
	EndIf;
	
	FilterCompanyOnChange(Undefined);
	
EndProcedure

&AtServer
Function GetCompany(Account)
	Return Common.ObjectAttributeValue(Account, "Owner");
EndFunction

&AtClient
Procedure OpenSelectAccountForm(Item)
	
	ParameterStructure = New Structure;
	
	FilterArray = New Array;
	
	If ValueIsFilled(FilterCompany) Then
		
		FilterArray.Add(FilterCompany);
		
	Else
		
		FilterArray = CompaniesList.UnloadValues();
		
	EndIf;
	
	FilterArray.Add(PredefinedValue("Catalog.Companies.EmptyRef"));
	
	StructureFilter = New Structure();
	StructureFilter.Insert("Owner", FilterArray);
	
	ParameterStructure.Insert("Filter", StructureFilter);
	
	OpenForm("CommonForm.SelectBankCashAccount", ParameterStructure, Item);
	
EndProcedure

&AtServer
Procedure FillCompaniesList()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Companies.Ref AS Ref
	|FROM
	|	Catalog.Companies AS Companies";
	
	CompaniesList.LoadValues(Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

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