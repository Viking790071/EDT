#Region Public

// Opens a dialog for batch editing of attributes for objects selected in a list.
//
// Parameters:
//  ListItem  - FormTable       - a form item that contains the list.
//  ListAttribute - DynamicList - a form attribute that contains the list.
//
Procedure ChangeSelectedItems(ListItem, Val ListAttribute = Undefined) Export
	
	If ListAttribute = Undefined Then
		Form = ListItem.Parent;
		While TypeOf(Form) <> Type("ClientApplicationForm") Do
			Form = Form.Parent;
		EndDo;
		
		Try
			ListAttribute = Form.List;
		Except
			ListAttribute = Undefined;
		EndTry;
	EndIf;
	
	SelectedRows = ListItem.SelectedRows;
	
	FormParameters = New Structure("ObjectsArray", New Array);
	If TypeOf(ListAttribute) = Type("DynamicList") Then
		FormParameters.Insert("SettingsComposer", ListAttribute.SettingsComposer);
	EndIf;
	
	For Each SelectedRow In SelectedRows Do
		If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
		
		CurrentRow = ListItem.RowData(SelectedRow);
		If CurrentRow <> Undefined Then
			FormParameters.ObjectsArray.Add(CurrentRow.Ref);
		EndIf;
	EndDo;
	
	If FormParameters.ObjectsArray.Count() = 0 Then
		ShowMessageBox(, NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot execute the command for the specified object.'; pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut çalıştırılamaz.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		Return;
	EndIf;
		
	OpenForm("DataProcessor.BatchEditAttributes.Form", FormParameters);
	
EndProcedure

#EndRegion
