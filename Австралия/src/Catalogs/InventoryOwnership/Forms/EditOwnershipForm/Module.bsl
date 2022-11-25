#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillOwnershipTable();
	
	Items.OwnershipTable.RowFilter = New FixedStructure("InStock", True);
	
EndProcedure

#EndRegion

#Region OwnershipTableFormTableItemsEventHandlers

&AtClient
Procedure OwnershipTableValueChoice(Item, Value, StandardProcessing)
	
	NotifyChoice(OwnershipTable.FindByID(Value).Ownership);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillOwnershipTable()
	
	DocumentData = GetFromTempStorage(Parameters.DocumentDataTempStorageAddress);
	
	KeyFieldsString = StringFunctionsClientServer.StringFromSubstringArray(DocumentData.Parameters.KeyFields);
	SearchFilter = New Structure(KeyFieldsString);
	
	KeyTableRow = DocumentData.KeyTable.Get(Parameters._KeyTableRowIndex);
	
	FillPropertyValues(SearchFilter, KeyTableRow);
	
	If KeyTableRow._UseSerialNumbers Then
		SearchFilter.Insert("SerialNumber", Parameters.SerialNumber);
	EndIf;
	
	OwnershipItems = GetOwnershipItems();
	
	For Each Ownership In OwnershipItems Do
		
		NewRow = OwnershipTable.Add();
		NewRow.Ownership = Ownership;
		NewRow.Balance = GetBalance(DocumentData.Parameters, SearchFilter, Ownership);
		NewRow.InStock = (NewRow.Balance > 0);
		
		If Parameters.CurrentRow = Ownership Then
			Items.OwnershipTable.CurrentRow = NewRow.GetID();
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetOwnershipItems()
	
	Query = New Query;
	
	Query.Text =
	"SELECT ALLOWED
	|	InventoryOwnership.Ref AS Ref
	|FROM
	|	Catalog.InventoryOwnership AS InventoryOwnership
	|
	|ORDER BY
	|	InventoryOwnership.Description";
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

&AtServer
Function GetBalance(Parameters, RowKeyData, Ownership)
	
	Return InventoryOwnershipServer.GetBalanceForInventoryOwnershipForm(Parameters, RowKeyData, Ownership);
	
EndFunction

#EndRegion