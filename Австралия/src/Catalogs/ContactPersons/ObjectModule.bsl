#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		CounterpartyAttributes = Common.ObjectAttributesValues(FillingData, "IsFolder,Responsible");
		
		If Not CounterpartyAttributes.IsFolder Then
			Owner		= FillingData;
			Responsible	= CounterpartyAttributes.Responsible;
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		CreationDate = CurrentSessionDate();
	EndIf;
	
	RolesList = "";
	For Each RoleTP In Roles Do
		RolesList = RolesList + ?(RolesList = "","",", ") + RoleTP.Role;
	EndDo;
	
	// Set attribute AdditionalOrderingAttribute
	If Not Cancel And AdditionalOrderingAttribute = 0 Then
		
		SetPrivilegedMode(True);
		
		Query = New Query(
		"SELECT ALLOWED TOP 1
		|	Table.AdditionalOrderingAttribute AS AdditionalOrderingAttribute
		|FROM
		|	Catalog.ContactPersons AS Table
		|
		|ORDER BY
		|	AdditionalOrderingAttribute DESC");
		
		Selection = Query.Execute().Select();
		Selection.Next();
		
		AdditionalOrderingAttribute = ?(Not ValueIsFilled(Selection.AdditionalOrderingAttribute), 1, Selection.AdditionalOrderingAttribute + 1);
		
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ClearAttributeMainContactPerson();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// No execute action in the data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Duplicate rules index
	If AdditionalProperties.Property("DuplicateRulesIndexTableAddress") Then
		DuplicateRulesIndexTable = GetFromTempStorage(AdditionalProperties.DuplicateRulesIndexTableAddress);
		AdditionalProperties.Insert("DuplicateRulesIndexTable", DuplicateRulesIndexTable);
	Else
		DuplicatesBlocking.PrepareDuplicateRulesIndexTable(Ref, AdditionalProperties);
	EndIf;
	
	If AdditionalProperties.Property("ModificationTableAddress") Then
		ModificationTable = GetFromTempStorage(AdditionalProperties.ModificationTableAddress);
		DuplicatesBlocking.ChangeDuplicatesData(ModificationTable, Cancel);
	EndIf;
	
	DriveServer.ReflectDuplicateRulesIndex(AdditionalProperties, Ref, Cancel);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillByDefault()
	
	If Not ValueIsFilled(Responsible) Then
		Responsible = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	EndIf;
	
	CreationDate = CurrentSessionDate();
	
EndProcedure

Procedure ClearAttributeMainContactPerson()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Counterparties.Ref AS Ref
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.ContactPerson = &ContactPerson";
	
	Query.SetParameter("ContactPerson", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		CatalogObject = Selection.Ref.GetObject();
		CatalogObject.ContactPerson = Undefined;
		CatalogObject.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf