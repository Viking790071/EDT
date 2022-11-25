
#Region EventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ConstantsList.Clear();
	For CurIndex = 0 To Parameters.MetadataNamesArray.UBound() Do
		Row = ConstantsList.Add();
		Row.AutoRecordPictureIndex = Parameters.AutoRecordsArray[CurIndex];
		Row.PictureIndex                = 2;
		Row.MetaFullName                 = Parameters.MetadataNamesArray[CurIndex];
		Row.Description                  = Parameters.PresentationsArray[CurIndex];
	EndDo;
	
	AutoRecordTitle = NStr("ru = 'Авторегистрация для узла ""%1""'; en = 'Autostage for node %1'; pl = 'Automatyczna rejestracja dla węzła %1';es_ES = 'Auto registro para el nodo %1';es_CO = 'Auto registro para el nodo %1';tr = '%1 düğümü için otomatik hazırla';it = 'Autostage per nodo %1';de = 'Automatische Aufbereitung für Knoten %1'");
	
	Items.AutoRecordDecoration.Title = StrReplace(AutoRecordTitle, "%1", Parameters.ExchangeNode);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CurParameters = SetFormParameters();
	Items.ConstantsList.CurrentRow = CurParameters.CurrentRow;
EndProcedure

&AtClient
Procedure OnReopen()
	CurParameters = SetFormParameters();
	Items.ConstantsList.CurrentRow = CurParameters.CurrentRow;
EndProcedure

#EndRegion

#Region ConstantListFormTableItemEventHandlers
//

&AtClient
Procedure ConstantListSelection(Item, RowSelected, Field, StandardProcessing)
	
	PerformConstantSelection();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

// Selects a constant.
//
&AtClient
Procedure SelectConstant(Command)
	
	PerformConstantSelection();
	
EndProcedure

#EndRegion

#Region Private
//

// Performs the selection and notifies of it.
//
&AtClient
Procedure PerformConstantSelection()
	Data = New Array;
	For Each CurrentRowItem In Items.ConstantsList.SelectedRows Do
		curRow = ConstantsList.FindByID(CurrentRowItem);
		Data.Add(curRow.MetaFullName);
	EndDo;
	NotifyChoice(Data);
EndProcedure	

&AtServer
Function SetFormParameters()
	Result = New Structure("CurrentRow");
	If Parameters.ChoiceInitialValue <> Undefined Then
		Result.CurrentRow = MetaNameRowID(Parameters.ChoiceInitialValue);
	EndIf;
	Return Result;
EndFunction

&AtServer
Function MetaNameRowID(FullMetadataName)
	Data = FormAttributeToValue("ConstantsList");
	curRow = Data.Find(FullMetadataName, "MetaFullName");
	If curRow <> Undefined Then
		Return curRow.GetID();
	EndIf;
	Return Undefined;
EndFunction

#EndRegion
