
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("StartDate"			, StartDate);
	Parameters.Property("Company"			, Company);
	Parameters.Property("TypeOfAccounting"	, TypeOfAccounting);
	Parameters.Property("ChartOfAccounts"	, ChartOfAccounts);
	Parameters.Property("DocumentType"		, DocumentType);
	
	If Not Parameters.Property("EndDate", EndDate) Or Not ValueIsFilled(EndDate) Then
		EndDate = '39991231';
	EndIf;
	
	If Parameters.Property("Entries") Then
		
		Entries = Parameters.Entries.Unload();
		Entries.GroupBy("EntriesTemplate");
		
		For Each Row In Entries Do
			NewRow = FilteredEntriesTemplates.Add();
			NewRow.EntriesTemplate = Row.EntriesTemplate;
			FillPropertyValues(NewRow, NewRow.EntriesTemplate);
		EndDo;
		
	EndIf;
	
	If Parameters.Property("TemplateParameters") Then
		
		TransactionTemplateParameters = Parameters.TemplateParameters.Unload();
		TransactionTemplateParameters.Columns.Add("ParameterValues");
		
		For Each Parameter In TransactionTemplateParameters Do
			
			Parameter.ParameterValues = WorkWithArbitraryParameters.GetValuesArray(Parameters.ParametersValues, Parameter.ValuesConnectionKey, "Parameters");
			
		EndDo;
		
		TemplateParameters.Load(TransactionTemplateParameters);
		
	EndIf;
	
	RefreshAtServer();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure EntriesTemplatesValueChoice(Item, Value, StandardProcessing)
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	
	NewRow = FilteredEntriesTemplates.Add();
	FillPropertyValues(NewRow, CurrentRow);
	
	EntriesTemplates.Delete(EntriesTemplates.IndexOf(CurrentRow));
EndProcedure

&AtClient
Procedure FilteredEntriesTemplatesValueChoice(Item, Value, StandardProcessing)
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	
	NewRow = EntriesTemplates.Add();
	FillPropertyValues(NewRow, CurrentRow);
	
	FilteredEntriesTemplates.Delete(FilteredEntriesTemplates.IndexOf(CurrentRow));
EndProcedure

&AtClient
Procedure FilteredEntriesTemplatesBeforeDeleteRow(Item, Cancel)
	CurrentRow	 = Item.CurrentData;
	
	NewRow		 = EntriesTemplates.Add();
	FillPropertyValues(NewRow, CurrentRow);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)
	RefreshAtServer();
EndProcedure

&AtClient
Procedure OK(Command)
	Close(MakeRefArray());
EndProcedure
	
#EndRegion

#Region Private

&AtServer
Procedure RefreshAtServer()
	
	EntriesTemplates.Clear();
	
	TemplateAttributes = New Structure("StartDate, EndDate, Company, TypeOfAccounting, DocumentType, ChartOfAccounts");
	FillPropertyValues(TemplateAttributes, ThisObject);
		
	TemplateTable = WorkWithArbitraryParameters.GetEntriesTemplates(TemplateAttributes,	TemplateParameters.Unload());	
	
	For Each Row In TemplateTable Do
		
		FilteredTemplatesRows = FilteredEntriesTemplates.FindRows(New Structure("EntriesTemplate", Row.EntriesTemplate));
		If FilteredTemplatesRows.Count() = 0 Then
			NewRow = EntriesTemplates.Add();
			FillPropertyValues(NewRow, Row);
		EndIf;
		
	EndDo;
		
EndProcedure

&AtServer
Function MakeRefArray()
	
	AddressInStorage = PutToTempStorage(FilteredEntriesTemplates.Unload(,"EntriesTemplate").UnloadColumn("EntriesTemplate"));
	
	Return AddressInStorage;
	
EndFunction

#EndRegion