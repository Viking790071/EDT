
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountsForFilling = GLAccountsInDocuments.GetGLAccountsForFillingByParameters(Parameters);
	FillForm(GLAccountsForFilling);
	
	ProductDescription = "";
	
	If ValueIsFilled(Products) Then
		ProductDescription = Common.ObjectAttributeValue(Products, "Description");
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'GL accounts: %1'; ru = 'Счета учета: %1';pl = 'Księga główna konta: %1';es_ES = 'Cuentas del libro mayor: %1';es_CO = 'Cuentas del libro mayor: %1';tr = 'Muhasebe hesapları: %1';it = 'Conto mastro: %1';de = 'Hauptbuch-Konten: %1'"),
		ProductDescription);
		
	Height = 16;
	
	If Parameters.Property("IsReadOnly") Then
		Items.FormOK.Enabled = Not Parameters.IsReadOnly;
		Items.GroupAttribute.ReadOnly = Parameters.IsReadOnly;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Exit And (Modified Or Select) Then
		Cancel = True;
		Return;
	EndIf;
	
	If Modified And Not Select Then
		Cancel = True;
		QuestionText = NStr("en = 'Data was changed. Do you want to save the changes?'; ru = 'Данные были изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Datos se han cambiado. ¿Quiere guardar los cambios?';es_CO = 'Datos se han cambiado. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Salva le modifiche?';de = 'Daten wurden geändert. Wollen Sie die Änderungen speichern?'");
		
		Notify = New NotifyDescription("QuestionBeforeCloseEnd", ThisForm);
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
		
		AttributeItems = Thisobject.ChildItems.GroupAttribute.ChildItems;
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

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Cancel(Command)
	
	Select = False;
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	Select = True;
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillForm(Parameters)
	
	FormItems = Items.GroupAttribute.ChildItems;
	For Each Item In FormItems Do
		Parameters.Property(Item.Name, ThisForm[Item.Name]);
		Item.Visible = Parameters.Property(Item.Name);
	EndDo;
	
	Parameters.Property("TableName",	TableName);	
	Parameters.Property("Products",		Products);
	
	If Parameters.TableName = "Expenses" Then
		Items.InventoryGLAccount.Title = NStr("en = 'Expenses'; ru = 'Расходы';pl = 'Rozchody';es_ES = 'Gastos';es_CO = 'Gastos';tr = 'Masraflar';it = 'Spese';de = 'Ausgaben'");
	ElsIf Parameters.Property("InventoryToGLAccount") Then
		Items.InventoryGLAccount.Title = NStr("en = 'From'; ru = 'От';pl = 'Od';es_ES = 'Desde';es_CO = 'Desde';tr = 'İtibaren';it = 'Da';de = 'Von'");
	EndIf;
	
	If Parameters.Property("RestrictInventoryGLAccount") Then
		SetRestrictInventoryGLAccount(Parameters.RestrictInventoryGLAccount);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetRestrictInventoryGLAccount(StructureRestrictInventoryGLAccount)
	
	If StructureRestrictInventoryGLAccount.Property("ExcludeTypeOfAccount") Then
		
		ArrayTypeOfAccount = New Array;
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	GLAccountsTypes.Ref AS TypeOfAccount
		|FROM
		|	Enum.GLAccountsTypes AS GLAccountsTypes
		|WHERE
		|	GLAccountsTypes.Ref <> &Ref";
		
		Query.SetParameter("Ref", StructureRestrictInventoryGLAccount.ExcludeTypeOfAccount);
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			ArrayTypeOfAccount.Add(SelectionDetailRecords.TypeOfAccount);
		EndDo;
		
		Values					= New FixedArray(ArrayTypeOfAccount);
		ChoiceParameterFilter	= New ChoiceParameter("Filter.TypeOfAccount", Values);
		ArrayParameters			= New Array();
		ArrayParameters.Add(ChoiceParameterFilter);
		ChoiceParameterFilter	= New ChoiceParameter("NotShowAllAccounts", True);
		ArrayParameters.Add(ChoiceParameterFilter);
		FixedArrayParameters	= New FixedArray(ArrayParameters);
		Items.InventoryGLAccount.ChoiceParameters = FixedArrayParameters;
	
	EndIf;
	
EndProcedure

&AtClient
Function CheckFillingAtClient()
	
	Cancel = False;
	
	FormItems = Items.GroupAttribute.ChildItems;
	For Each Item In FormItems Do
		If Item.Visible And Not ValueIsFilled(ThisForm[Item.Name]) Then
			MessageText = CommonClientServer.FillingErrorText("Field", "FillType", Item.Title);
			Field = Item.Name;
			CommonClientServer.MessageToUser(MessageText, , Field, "", Cancel);
		EndIf;
	EndDo;
	
	Return Not Cancel;
	
EndFunction

#EndRegion