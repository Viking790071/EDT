#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DoublesList.Parameters.SetParameterValue("TIN", TrimAll(Parameters.TIN));
	
	Title =  NStr("en = 'TIN duplicate list'; ru = 'Список дублей по ИНН';pl = 'Lista duplikatów według NIP';es_ES = 'Lista de duplicados de NIF';es_CO = 'Lista de duplicados de NIF';tr = 'VKN yedek listesi';it = 'Elenco duplicati per cod.fiscale';de = 'Duplikatliste der Umsatzsteueridentifikationsnummer'");
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure DuplicatesListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	TransferParameters = New Structure("Key", Item.CurrentData.Ref);
	TransferParameters.Insert("CloseOnOwnerClose", True);
	
	OpenForm("Catalog.Counterparties.ObjectForm",
				  TransferParameters, 
				  Item,
				  ,
				  ,
				  ,
				  New NotifyDescription("HandleItemEdit", ThisForm));
	
EndProcedure
			  
&AtClient
Procedure DoublesListOnActivateRow(Item)
	
	DataCurrentRows = Items.DoublesList.CurrentData;
	
	If Not DataCurrentRows = Undefined Then
		
		AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenDocumentsOnCounterparty(Command)
	
	CurrentDataOfList = Items.DoublesList.CurrentData;
	If CurrentDataOfList = Undefined Then
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта!';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Return;
	EndIf;
	
	FilterStructure = New Structure("Counterparty", CurrentDataOfList.Ref);
	FormParameters = New Structure("SettingsKey, Filter, GenerateOnOpen", "Counterparty", FilterStructure, True);
	
	OpenForm("DataProcessor.CounterpartyDocuments.Form.CounterpartyDocuments", FormParameters, ThisForm,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure HandleItemEdit(ClosingResult, AdditionalParameters) Export
	Items.DoublesList.Refresh();
EndProcedure

// Procedure of the list string activation processor.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	CurrentDataOfList = Items.DoublesList.CurrentData;
	If CurrentDataOfList = Undefined Then
		Return;
	EndIf;
	
	Items.OpenDocumentsOnCounterparty.Title = "Documents on counterparty (" + GetCounterpartyDocumentsCount(CurrentDataOfList.Ref) + ")";
	
EndProcedure

&AtServerNoContext
Function GetCounterpartyDocumentsCount(Counterparty)
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	COUNT(DISTINCT CounterpartyDocuments.Ref) AS DocumentsCount
		|FROM
		|	FilterCriterion.CounterpartyDocuments(&Counterparty) AS CounterpartyDocuments";

	Query.SetParameter("Counterparty", Counterparty);

	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return 0;
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.DocumentsCount;
	EndIf;

EndFunction

#EndRegion
