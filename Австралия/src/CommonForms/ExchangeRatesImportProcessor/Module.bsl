
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ExchangeRatesImportProcessor = Common.ObjectAttributeValue(Catalogs.Companies.MainCompany, "ExchangeRatesImportProcessor");
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Modified Then 
		Cancel = True;
		If Exit Then
			MessageText = NStr("en = 'The changes will not be saved'; ru = 'Изменения не будут сохранены';pl = 'Zmiany nie zostaną zapisane';es_ES = 'Los cambios no serán guardados';es_CO = 'Los cambios no serán guardados';tr = 'Değişiklikler kaydedilmeyecek';it = 'Le modifiche non saranno salvate';de = 'Die Änderungen werden nicht gespeichert'");
		Else
			NotifyDescription = New NotifyDescription("AfterQuestionOnClose", ThisForm);
			ShowQueryBox(NotifyDescription, Nstr("en = 'Data has been changed. Do you want to save the changes?'; ru = 'Данные были изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';es_CO = 'Los datos han sido cambiados. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Salvare le modifiche?';de = 'Die Daten wurden geändert. Wollen Sie die Änderungen speichern?'"), QuestionDialogMode.YesNoCancel);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterQuestionOnClose(Result, AdditionalParameters) Export 
	
	If Result = DialogReturnCode.No Then 
		Modified = False;
		Close();
	ElsIf Result = DialogReturnCode.Yes Then
		SaveData();
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SaveAndCloseButton(Command)

	SaveData();
	Close();
	
EndProcedure

&AtClient
Procedure SaveButton(Command)

	SaveData();
	
EndProcedure

&AtClient
Procedure CancelButton(Command)
	Modified = False;
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SaveData()
	
	CompanyObject = Catalogs.Companies.MainCompany.GetObject();
	CompanyObject.ExchangeRatesImportProcessor = ExchangeRatesImportProcessor;
	CompanyObject.Write();
	Modified = False;

EndProcedure

#EndRegion
