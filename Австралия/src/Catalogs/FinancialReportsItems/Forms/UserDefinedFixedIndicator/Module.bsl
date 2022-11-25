
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ObjectData = Catalogs.FinancialReportsItems.FormOnCreateAtServer(ThisObject);
	IndicatorName = ObjectData.DescriptionForPrinting;
	Items.GroupAdditionalAttributes.Visible = Parameters.ShowRowCodeAndNote;
	Items.MarkItem.Visible = Parameters.ShowRowCodeAndNote;
	RefreshFormTitle();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Catalogs.FinancialReportsItems.FormBeforeWriteAtServer(ThisObject, CurrentObject, Cancel);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If ValueIsFilled(ItemAddressInTempStorage) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	RefreshFormTitle();

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(
		Item.EditText, 
		ThisObject, 
		"Object.Comment");
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FinishEditing(Command)
	
	FinancialReportingClient.FinishEditingReportItem(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure RefreshFormTitle()
	
	If ValueIsFilled(Object.Ref) Then
		Title = NStr("en = 'User-defined fixed indicator'; ru = 'Пользовательский фиксированный индикатор';pl = 'Zdefiniowany przez użytkownika stały wskaźnik';es_ES = 'Indicador fijo definido por el usuario';es_CO = 'Indicador fijo definido por el usuario';tr = 'Kullanıcı tanımlı sabit gösterge';it = 'Indicatore fisso definito dall''utente';de = 'Benutzerdefiniertes Festkennzeichen'");
	Else
		Title = NStr("en = 'User-defined fixed indicator (Create)'; ru = 'Пользовательский фиксированный индикатор (создание)';pl = 'Zdefiniowany przez użytkownika stały wskaźnik (Tworzenie)';es_ES = 'Indicador fijo definido por el usuario (Crear)';es_CO = 'Indicador fijo definido por el usuario (Crear)';tr = 'Kullanıcı tanımlı sabit gösterge (Oluştur)';it = 'Indicatore fisso personalizzato (Crea)';de = 'Benutzerdefiniertes Festkennzeichen (Erstellen)'");
	EndIf;
	
EndProcedure

#EndRegion
