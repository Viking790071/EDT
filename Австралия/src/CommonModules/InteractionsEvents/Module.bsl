///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

// An event handler when writing an email account.
Procedure OnWriteEmailAccount(Source, Cancel) Export

	If Source.DataExchange.Load Then
	
		Return;
	
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	               |	EmailMessageFolders.Ref
	               |FROM
	               |	Catalog.EmailMessageFolders AS EmailMessageFolders
	               |WHERE
	               |	EmailMessageFolders.PredefinedFolder
	               |	AND EmailMessageFolders.Owner = &Account";
	
	Query.SetParameter("Account",Source.Ref);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		EmailManagement.CreatePredefinedEmailsFoldersForAccount(Source.Ref);
	EndIf;

EndProcedure

// FillAccessValuesSetsOfTabularSections* subscription handler for the BeforeWrite event fills 
// access values of the AccessValuesSets object tabular section when the #ByValuesSets template is 
// used to restrict access to the object.
//  The AccessManagement subsystem can be used when
// the specified subscription does not exist if the sets are not applied for the specified purpose.
//
// Parameters:
//  Source - CatalogObject,
//                    DocumentObject,
//                    ChartOfCharacteristicTypesObject,
//                    ChartOfAccountsObject,
//                    ChartOfCalculationTypesObject,
//                    BusinessProcessObject,
//                    TaskObject,
//                    ExchangePlanObject - a data object passed to the BeforeWrite event subscription.
//
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//
//  WriteMode - Boolean - a parameter passed to the BeforeWrite event subscription when the type of 
//                    the Source parameter is DocumentObject.
//
//  PostingMode - Boolean - parameter passed to the BeforeWrite event subscription when the Source 
//                    parameter type is DocumentObject.
//
Procedure FillAccessValuesSetsForTabularSections(Source, Cancel = Undefined, WriteMode = Undefined, PostingMode = Undefined) Export
	
	// DataExchange.Import is checked within the call.
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.FillAccessValuesSetsForTabularSections(Source, Cancel, WriteMode, PostingMode);
	EndIf;
	
EndProcedure

// Gets choice data for interaction documents.
Procedure ChoiceDataGetProcessing(DocumentName, ChoiceData, Parameters, StandardProcessing) Export
	
	StandardProcessing = False;
	
	QueryText = "SELECT TOP 50 ALLOWED DISTINCT
	|	DocumentInteractions.Ref AS Ref
	|FROM
	|	#DocumentName AS DocumentInteractions
	|WHERE
	|	DocumentInteractions.Subject LIKE &SearchString
	|	OR DocumentInteractions.Number LIKE &SearchString";
	
	QueryText = StrReplace(QueryText, "#DocumentName", "Document" + "." + DocumentName);
	Query = New Query(QueryText);
	Query.SetParameter("SearchString", Parameters.SearchString + "%");
	
	ChoiceData = New ValueList;
	ChoiceData.LoadValues(Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

Procedure FillAccessValuesSets(Object, Table) Export
	
	InteractionsOverridable.OnFillingAccessValuesSets(Object, Table);
	
	If Table.Count() = 0 Then
		If TypeOf(Object) = Type("DocumentObject.Meeting") 
			Or TypeOf(Object) = Type("DocumentObject.PlannedInteraction") 
			Or TypeOf(Object) = Type("DocumentObject.SMSMessage") 
			Or TypeOf(Object) = Type("DocumentObject.PhoneCall") Then
			
			// The default restriction logic is as follows: an object is available if Author or EmployeeResponsible are available.
			// Restriction by EmailAccounts.
			
			SetNumber = 1;

			TabRow = Table.Add();
			TabRow.SetNumber     = SetNumber;
			TabRow.AccessValue = Object.Author;

			// Restriction by Person responsible.
			SetNumber = SetNumber + 1;

			TabRow = Table.Add();
			TabRow.SetNumber     = SetNumber;
			TabRow.AccessValue = Object.EmployeeResponsible;
			
		ElsIf TypeOf(Object) = Type("DocumentObject.IncomingEmail") Then
			
			// The default restriction logic is as follows: an object is available if EmployeeResponsible or Account are available.
			// Restriction by EmailAccounts.
			
			SetNumber = 1;

			TabRow = Table.Add();
			TabRow.SetNumber     = SetNumber;
			TabRow.AccessValue = Object.Account;

			// Restriction by Person responsible.
			SetNumber = SetNumber + 1;

			TabRow = Table.Add();
			TabRow.SetNumber     = SetNumber;
			TabRow.AccessValue = Object.EmployeeResponsible;
			
		ElsIf TypeOf(Object) = Type("DocumentObject.OutgoingEmail") Then
			
			// The default restriction logic is as follows: an object is available if EmployeeResponsible, Account,
			// or Author is available.

			SetNumber = 1;

			TableRow = Table.Add();
			TableRow.SetNumber     = SetNumber;
			TableRow.AccessValue = Object.Account;

			SetNumber = SetNumber + 1;

			TableRow = Table.Add();
			TableRow.SetNumber     = SetNumber;
			TableRow.AccessValue = Object.Author;

			SetNumber = SetNumber + 1;

			TableRow = Table.Add();
			TableRow.SetNumber     = SetNumber;
			TableRow.AccessValue = Object.EmployeeResponsible;
			
		EndIf;	
	EndIf;
	
EndProcedure

#EndRegion
