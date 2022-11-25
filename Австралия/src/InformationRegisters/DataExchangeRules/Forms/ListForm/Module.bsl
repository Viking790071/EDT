#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ExchangePlansWithRulesFromFile") Then
		
		Items.RulesSource.Visible = False;
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"RulesSource",
			Enums.DataExchangeRulesSources.File,
			DataCompositionComparisonType.Equal);
		
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UpdateAllStandardRules(Command)
	
	UpdateAllStandardRulesAtServer();
	Items.List.Refresh();
	
	ShowUserNotification(NStr("ru = 'Обновление правил успешно завершено.'; en = 'The rule update is completed.'; pl = 'Aktualizacja reguł zakończona pomyślnie.';es_ES = 'Reglas se han actualizado con éxito.';es_CO = 'Reglas se han actualizado con éxito.';tr = 'Kurallar başarıyla güncellendi.';it = 'L''aggiornamento regola è stato completato.';de = 'Regeln werden erfolgreich aktualisiert.'"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateAllStandardRulesAtServer()
	
	DataExchangeServer.UpdateDataExchangeRules();
	
	RefreshReusableValues();
	
EndProcedure

&AtClient
Procedure UseStandardRules(Command)
	UseStandardRulesAtServer();
	Items.List.Refresh();
	ShowUserNotification(NStr("ru = 'Обновление правил успешно завершено.'; en = 'The rule update is completed.'; pl = 'Aktualizacja reguł zakończona pomyślnie.';es_ES = 'Reglas se han actualizado con éxito.';es_CO = 'Reglas se han actualizado con éxito.';tr = 'Kurallar başarıyla güncellendi.';it = 'L''aggiornamento regola è stato completato.';de = 'Regeln werden erfolgreich aktualisiert.'"));
EndProcedure

&AtServer
Procedure UseStandardRulesAtServer()
	
	For Each Record In Items.List.SelectedRows Do
		RecordManager = InformationRegisters.DataExchangeRules.CreateRecordManager();
		FillPropertyValues(RecordManager, Record);
		RecordManager.Read();
		RecordManager.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate;
		HasErrors = False;
		InformationRegisters.DataExchangeRules.ImportRules(HasErrors, RecordManager);
		If Not HasErrors Then
			RecordManager.Write();
		EndIf;
	EndDo;
	
	DataExchangeServerCall.ResetObjectsRegistrationMechanismCache();
	RefreshReusableValues();
	
EndProcedure

#EndRegion
