
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillInPrintFormsArchivingTable();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PrintFormsArchivingTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	ChangeAtClient();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Create(Command)
	
	NotifyDescription = New NotifyDescription("ArchivingSettingCreateEnd", ThisObject);
	
	OpenForm("DataProcessor.PrintFormsArchivingSettings.Form.CompanySettingForm", , ThisObject, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure Change(Command)
	
	ChangeAtClient();
	
EndProcedure

&AtClient
Procedure Delete(Command)
	
	ArrayToDelete = New Array;
	
	For Each ID In Items.PrintFormsArchivingTable.SelectedRows Do
		
		Row = PrintFormsArchivingTable.FindByID(ID);
		If Row <> Undefined Then
			ArrayToDelete.Add(Row);
		EndIf;
		
	EndDo;
	
	For Each ArrayItem In ArrayToDelete Do
		
		If ValueIsFilled(ArrayItem.Company) Then
			DeleteRecordSet(ArrayItem.Company);
			PrintFormsArchivingTable.Delete(ArrayItem);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillInPrintFormsArchivingTable()
	
	PrintFormsArchivingTable.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PrintFormsArchivingSettings.Company AS Company,
	|	PrintFormsArchivingSettings.DocumentType AS DocumentType,
	|	MetadataObjectIDs.Synonym AS Synonym
	|FROM
	|	InformationRegister.PrintFormsArchivingSettings AS PrintFormsArchivingSettings
	|		INNER JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON PrintFormsArchivingSettings.DocumentType = MetadataObjectIDs.Ref
	|TOTALS BY
	|	Company";
	
	QueryResult = Query.Execute();
	
	SelectionCompany = QueryResult.Select(QueryResultIteration.ByGroups);
	While SelectionCompany.Next() Do
		
		RowTable = PrintFormsArchivingTable.Add();
		RowTable.Company = SelectionCompany.Company;
		
		DocTypeList = New ValueList;
		
		DocTypeSelection = SelectionCompany.Select();
		While DocTypeSelection.Next() Do
			
			DocTypeList.Add(DocTypeSelection.DocumentType, DocTypeSelection.Synonym);
			
		EndDo;
		
		RowTable.DocumentTypes = DocTypeList;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeAtClient()
	
	CurrentData = Items.PrintFormsArchivingTable.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("ArchivingSettingChangeEnd",
		ThisObject,
		New Structure("CurrentData", CurrentData));
	
	FormParameters = New Structure;
	FormParameters.Insert("Company", CurrentData.Company);
	FormParameters.Insert("DocumentTypesArray", CurrentData.DocumentTypes.UnloadValues());
	
	OpenForm("DataProcessor.PrintFormsArchivingSettings.Form.CompanySettingForm",
		FormParameters,
		ThisObject, , , ,
		NotifyDescription);
	
EndProcedure

&AtServer
Procedure DeleteRecordSet(Company)
	
	If ValueIsFilled(Company) Then
		RecordSet = InformationRegisters.PrintFormsArchivingSettings.CreateRecordSet();
		RecordSet.Filter.Company.Set(Company);
		RecordSet.Write();
	EndIf;
	
EndProcedure

&AtServer
Procedure AddChangeRecordSet(Company, DocumentTypes)
	
	If ValueIsFilled(Company) Then
		
		RecordSet = InformationRegisters.PrintFormsArchivingSettings.CreateRecordSet();
		RecordSet.Filter.Company.Set(Company);
		
		For Each ListItem In DocumentTypes Do
			NewRecord = RecordSet.Add();
			NewRecord.Company = Company;
			NewRecord.DocumentType = ListItem.Value;
		EndDo;
		
		RecordSet.Write();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ArchivingSettingCreateEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = Undefined OR ClosingResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If ClosingResult.DocumentTypeList.Count() > 0 Then
		
		NewRow = PrintFormsArchivingTable.Add();
		NewRow.Company = ClosingResult.Company;
		NewRow.DocumentTypes = ClosingResult.DocumentTypeList;
		
		AddChangeRecordSet(ClosingResult.Company, ClosingResult.DocumentTypeList);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ArchivingSettingChangeEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = Undefined OR ClosingResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If ClosingResult.DocumentTypeList.Count() > 0 Then
		AdditionalParameters.CurrentData.Company = ClosingResult.Company;
		AdditionalParameters.CurrentData.DocumentTypes = ClosingResult.DocumentTypeList;
	Else
		PrintFormsArchivingTable.Delete(AdditionalParameters.CurrentData);
	EndIf;
	
	AddChangeRecordSet(ClosingResult.Company, ClosingResult.DocumentTypeList);
	
EndProcedure

#EndRegion