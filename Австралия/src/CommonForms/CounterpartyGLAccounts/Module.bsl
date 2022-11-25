
#Region FormEventHandlers

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Exit And (Modified Or Select) Then
		Cancel = True;
		Return;
	EndIf;
	
	If Modified And Not Select Then
		Cancel = True;
		QuestionText = NStr("en = 'Data was changed. Do you want to save the changes?'; ru = 'Данные были изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Datos se han cambiado. ¿Quiere guardar los cambios?';es_CO = 'Datos se han cambiado. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Salvare le modifiche?';de = 'Daten wurden geändert. Wollen Sie die Änderungen speichern?'");
		
		Notify = New NotifyDescription("QuestionBeforeCloseEnd", ThisObject);
		ShowQueryBox(Notify, QuestionText, QuestionDialogMode.YesNoCancel,, DialogReturnCode.Yes);
	EndIf;
	
	If Select And Not Cancel Then
		Cancel = Not CheckFillingAtClient();
	EndIf;
	
	If Cancel Then
		Select = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Select Then
		
		ResultStructure = New Structure;		
		
		AttributeItems = ThisObject.ChildItems;
		For Each Item In AttributeItems Do
			If ValueIsFilled(ThisObject[Item.Name]) Then
				ResultStructure.Insert(Item.Name, ThisObject[Item.Name]);
			EndIf;
		EndDo;
		
		GLAccountsInDocumentsServerCall.GetGLAccountsDescription(ResultStructure);
		ResultStructure.Insert("TableName", TableName);
		
		NotifyChoice(ResultStructure);
	EndIf;

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountsForFilling = GLAccountsInDocuments.GetGLAccountsForFillingByParameters(Parameters);
	FillForm(GLAccountsForFilling);
	Height = 12;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	Select = True;
	Close();

EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Select = False;
	Modified = False;
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function CheckFillingAtClient()
	
	Cancel = False;
	
	FormItems = ThisObject.ChildItems;
	For Each Item In FormItems Do
		If Item.Visible And Not ValueIsFilled(ThisObject[Item.Name]) Then
			MessageText = CommonClientServer.FillingErrorText("Field", "FillType", Item.Title);
			Field = Item.Name;
			CommonClientServer.MessageToUser(MessageText, , Field, "", Cancel);
		EndIf;
	EndDo;
	
	Return Not Cancel;
	
EndFunction

&AtServer
Procedure FillForm(Parameters)
	
	FormItems = ThisObject.ChildItems;
	For Each Item In FormItems Do
		Parameters.Property(Item.Name, ThisObject[Item.Name]);
		Item.Visible = Parameters.Property(Item.Name);
	EndDo;
	
	Parameters.Property("TableName",	TableName);	
	
EndProcedure

#EndRegion