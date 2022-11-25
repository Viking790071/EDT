#Region GeneralPurposeProceduresAndFunctions

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogPeripherals(Command)
	
	If Modified Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Data is not written yet. You can start editing the ""Companies"" catalog only after the data is written.'; ru = 'Данные еще не записаны! Переход к редактированию справочника ""Организации"" возможен только после записи данных!';pl = 'Dane nie są jeszcze zapisane. Możesz rozpocząć edytowanie katalogu ""Firmy"" dopiero po zapisaniu danych.';es_ES = 'Datos aún no se han grabado. Usted puede empezar la edición del catálogo ""Empresas"" solo después de haber grabado los datos.';es_CO = 'Datos aún no se han grabado. Usted puede empezar la edición del catálogo ""Empresas"" solo después de haber grabado los datos.';tr = 'Veriler henüz yazılmamıştır. ""İş yerleri"" kataloğunu sadece veri yazıldıktan sonra düzenlemeye başlayabilirsiniz.';it = 'I dati non sono ancora stati registrati! La transizione alla modifica della directory ""Organizzazione"" è possibile solo dopo aver registrato i dati!';de = 'Daten sind noch nicht geschrieben. Sie können den Katalog ""Firmen"" erst nach dem Schreiben der Daten bearbeiten.'");
		Message.Message();
		Return;
	EndIf;
	
	EquipmentManagerClient.RefreshClientWorkplace();
	OpenForm("Catalog.Peripherals.ListForm");
	
EndProcedure

&AtClient
Procedure OpenExchangeRulesWithPeripherals(Command)
	
	If Modified Then
		Mode = QuestionDialogMode.YesNo;
		MessageText = NStr("en = 'Data is not saved yet. You can go to the settings only after the data is saved.
			|Do you want to save the data?'; 
			|ru = 'Данные еще не сохранены. Вы можете перейти в настройки только после сохранения данных.
			|Сохранить данные?';
			|pl = 'Dane jeszcze nie są zapisane. Możesz przejść do ustawień tylko po zapisaniu danych.
			|Czy chcesz zapisać dane?';
			|es_ES = 'Los datos no se han guardado todavía. Sólo se puede ir a los ajustes después de que los datos se hayan guardado. 
			|¿Quiere guardar los datos?';
			|es_CO = 'Los datos no se han guardado todavía. Sólo se puede ir a los ajustes después de que los datos se hayan guardado. 
			|¿Quiere guardar los datos?';
			|tr = 'Veri henüz kaydedilmedi. Yalnızca veri kaydedildikten sonra ayarlara gidebilirsiniz.
			|Veriyi kaydetmek istiyor musunuz?';
			|it = 'I dati non sono ancora salvati. È possibile andare alle impostazioni solo dopo aver salvato i dati. 
			|Salvare i dati?';
			|de = 'Daten sind noch nicht gespeichert. Sie können zu den Einstellungen erst nach Speichern von Daten gehen.
			|Möchten Sie die Daten speichern?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("OpenExchangeRulesWithPeripheralsEnd", ThisObject), MessageText, Mode, 0);
        Return;
	EndIf;
	
	OpenExchangeRulesWithPeripheralsFragment();
EndProcedure

&AtClient
Procedure OpenExchangeRulesWithPeripheralsEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Write();
    Else
        Return;
    EndIf;
    
    OpenExchangeRulesWithPeripheralsFragment();

EndProcedure

&AtClient
Procedure OpenExchangeRulesWithPeripheralsFragment()
    
    RefreshInterface();
    OpenForm("Catalog.ExchangeWithOfflinePeripheralsRules.ListForm", , ThisForm);

EndProcedure

&AtClient
Procedure OpenWorkplaces(Command)
	
	OpenForm("Catalog.Workplaces.ListForm", , ThisForm);
	
EndProcedure

#EndRegion

#Region FormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.OpenExchangeRulesWithPeripherals.Enabled = ConstantsSet.UseOfflineExchangeWithPeripherals;
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	RefreshInterface();
	
EndProcedure

#EndRegion

#Region EventHandlersOfFormAttributes

&AtClient
Procedure FunctionalOptionUseOfflineExchangeWithPeripheralsOnChange(Item)
	
	Items.OpenExchangeRulesWithPeripherals.Enabled = ConstantsSet.UseOfflineExchangeWithPeripherals;
	
EndProcedure

#EndRegion
