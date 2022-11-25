
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// First of all, checking the access rights.
	If Not AccessRight("Administration", Metadata) Then
		Raise NStr("ru = 'Использование обработки в интерактивном режиме доступно только администратору.'; en = 'Running the data processor manually requires administrator rights.'; pl = 'Używanie przetwarzania danych w trybie interaktywnym jest dostępne tylko dla administratora.';es_ES = 'Uso del procesador de datos en el modo interactivo está disponible solo para el administrador';es_CO = 'Uso del procesador de datos en el modo interactivo está disponible solo para el administrador';tr = 'Etkileşimli modda veri işlemcisi kullanımı sadece yönetici için kullanılabilir.';it = 'L''utilizzo dell''elaborazione in modalità interattiva è disponibile solo per l''amministratore.';de = 'Die Verwendung des Datenprozessors im interaktiven Modus ist nur für Administratoren verfügbar.'");
	EndIf;
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Object.ExchangeFileName = Parameters.ExchangeFileName;
	Object.ExchangeRuleFileName = Parameters.ExchangeRuleFileName;
	Object.EventHandlerExternalDataProcessorFileName = Parameters.EventHandlerExternalDataProcessorFileName;
	Object.AlgorithmDebugMode = Parameters.AlgorithmDebugMode;
	Object.ReadEventHandlersFromExchangeRulesFile = Parameters.ReadEventHandlersFromExchangeRulesFile;
	
	FormHeader = NStr("ru = 'Настройка отладки обработчиков при %Event% данных'; en = 'Configure debigguing of %Event% handlers'; pl = 'Skonfiguruj debugowanie wydarzeń %Event%';es_ES = 'Configurar depuración de gestores de %Event%';es_CO = 'Configurar depuración de gestores de %Event%';tr = '%Event% işleyicilerinin hata ayıklamasını yapılandırın';it = 'Configurare il debug dei gestori %Event%';de = 'Konfigurieren Sie das Debugging von %Event%-Handlern.'");	
	Event = ?(Parameters.ReadEventHandlersFromExchangeRulesFile, NStr("ru = 'выгрузка'; en = 'export'; pl = 'eksportuj';es_ES = 'exportar';es_CO = 'exportar';tr = 'dışa aktar';it = 'esportazione';de = 'Export'"), NStr("ru = 'загрузке'; en = 'import'; pl = 'importuj';es_ES = 'importar';es_CO = 'importar';tr = 'içe aktar';it = 'importazione';de = 'import'"));
	FormHeader = StrReplace(FormHeader, "%Event%", Event);
	Title = FormHeader;
	
	ButtonTitle = NStr("ru = 'Сформировать модуль отладки %Event%'; en = 'Generate %Event% debug module'; pl = 'Wygeneruj moduł debugowania %Event%';es_ES = 'Generar módulo de depuración de %Event%';es_CO = 'Generar módulo de depuración de %Event%';tr = '%Event% hata ayıklama modülü oluştur';it = 'Genera modulo debug %Event%';de = 'Generieren Sie %Event% Debug-Modul'");
	Event = ?(Parameters.ReadEventHandlersFromExchangeRulesFile, NStr("ru = 'выгрузка'; en = 'export'; pl = 'eksportuj';es_ES = 'exportar';es_CO = 'exportar';tr = 'dışa aktar';it = 'esportazione';de = 'Export'"), NStr("ru = 'загрузки'; en = 'imports'; pl = 'pobierania';es_ES = 'descargas';es_CO = 'descargas';tr = 'içe aktarma';it = 'importa';de = 'importe'"));
	ButtonTitle = StrReplace(ButtonTitle, "%Event%", Event);
	Items.ExportHandlersCode.Title = ButtonTitle;
	
	SpecialTextColor = StyleColors.SpecialTextColor;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetVisibility();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AlgorithmDebugOnChange(Item)
	
	OnChangeOfChangeDebugMode();
	
EndProcedure

&AtClient
Procedure EventHandlerExternalDataProcessorFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileSelectionDialog = New FileDialog(FileDialogMode.Open);
	
	FileSelectionDialog.Filter     = NStr("ru = 'Файл внешней обработки обработчиков событий (*.epf)|*.epf'; en = 'Event handler external data processor file (*.epf)|*.epf'; pl = 'Zewnętrzny plik opracowania programów obsługi wydarzeń (*.epf)|*.epf';es_ES = 'Archivo del procesador de datos externo de los manipuladores de eventos (*.epf)|*.epf';es_CO = 'Archivo del procesador de datos externo de los manipuladores de eventos (*.epf)|*.epf';tr = 'Olay işleyicilerinin dış veri işlemci dosyası (*.epf) |*.epf';it = 'Il file di elaborazione esterna di elaboratori eventi (*.epf)|*.epf';de = 'Externe Datenverarbeitungsdatei von Ereignis-Handlern (*.epf)|*.epf'");
	FileSelectionDialog.DefaultExt = "epf";
	FileSelectionDialog.Title = NStr("ru = 'Выберите файл'; en = 'Select file'; pl = 'Wybierz plik';es_ES = 'Seleccionar un archivo';es_CO = 'Seleccionar un archivo';tr = 'Dosya seç';it = 'Selezione del file';de = 'Datei auswählen'");
	FileSelectionDialog.Preview = False;
	FileSelectionDialog.FilterIndex = 0;
	FileSelectionDialog.FullFileName = Item.EditText;
	FileSelectionDialog.CheckFileExist = True;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item", Item);
	
	Notification = New NotifyDescription("NameOfExternalDataProcessorFileOfEventHandlersChoiceProcessing", ThisObject, AdditionalParameters);
	FileSelectionDialog.Show(Notification);
	
EndProcedure

&AtClient
Procedure NameOfExternalDataProcessorFileOfEventHandlersChoiceProcessing(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	Object.EventHandlerExternalDataProcessorFileName = SelectedFiles[0];
	
	EventHandlerExternalDataProcessorFileNameOnChange(AdditionalParameters.Item);
	
EndProcedure

&AtClient
Procedure EventHandlerExternalDataProcessorFileNameOnChange(Item)
	
	SetVisibility();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Finish(Command)
	
	ClearMessages();
	
	If IsBlankString(Object.EventHandlerExternalDataProcessorFileName) Then
		
		MessageToUser(NStr("ru = 'Укажите имя файла внешней обработки.'; en = 'Enter the external data processor file name.'; pl = 'Podaj nazwę zewnętrznego pliku przetwarzania danych.';es_ES = 'Especificar un nombre del archivo del procesador de datos externo.';es_CO = 'Especificar un nombre del archivo del procesador de datos externo.';tr = 'Harici veri işlemcisi dosyasının adını girin.';it = 'Specificare il nome del file di elaborazione esterna.';de = 'Geben Sie einen Namen für die externe Datenprozessordatei an.'"), "EventHandlerExternalDataProcessorFileName");
		Return;
		
	EndIf;
	
	EventHandlerExternalDataProcessorFile = New File(Object.EventHandlerExternalDataProcessorFileName);
	
	Notification = New NotifyDescription("EventHandlerExternalDataProcessorFileExistanceCheckCompletion", ThisObject);
	EventHandlerExternalDataProcessorFile.BeginCheckingExistence(Notification);
	
EndProcedure

&AtClient
Procedure EventHandlerExternalDataProcessorFileExistanceCheckCompletion(Exists, AdditionalParameters) Export
	
	If Not Exists Then
		MessageToUser(NStr("ru = 'Указанный файл внешней обработки не существует.'; en = 'The specified external data processor file does not exist.'; pl = 'Określony plik zewnętrznego przetwarzania danych nie istnieje.';es_ES = 'El archivo especificado del procesador de datos externo no existe.';es_CO = 'El archivo especificado del procesador de datos externo no existe.';tr = 'Belirtilen harici veri işlemcisi dosyası mevcut değil.';it = 'Il file di elaborazione esterna specificato non esiste.';de = 'Die angegebene Datei des externen Datenprozessors existiert nicht.'"),
			"EventHandlerExternalDataProcessorFileName");
		Return;
	EndIf;
	
	ClosingParameters = New Structure;
	ClosingParameters.Insert("EventHandlerExternalDataProcessorFileName", Object.EventHandlerExternalDataProcessorFileName);
	ClosingParameters.Insert("AlgorithmDebugMode", Object.AlgorithmDebugMode);
	ClosingParameters.Insert("ExchangeRuleFileName", Object.ExchangeRuleFileName);
	ClosingParameters.Insert("ExchangeFileName", Object.ExchangeFileName);
	
	Close(ClosingParameters);
	
EndProcedure

&AtClient
Procedure OpenFile(Command)
	
	ShowEventHandlersInWindow();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetVisibility()
	
	OnChangeOfChangeDebugMode();
	
	// Highlighting wizard steps that require corrections with red color.
	SelectExternalDataProcessorName(IsBlankString(Object.EventHandlerExternalDataProcessorFileName));
	
	Items.OpenFile.Enabled = Not IsBlankString(Object.EventHandlersTempFileName);
	
EndProcedure

&AtClient
Procedure SelectExternalDataProcessorName(NeedToSelect = False) 
	
	Items.Step4Pages.CurrentPage = ?(NeedToSelect, Items.RedPage, Items.GreenPage);
	
EndProcedure

&AtClient
Procedure ExportHandlersCode(Command)
	
	// Data was exported earlier...
	If Not IsBlankString(Object.EventHandlersTempFileName) Then
		
		ButtonsList = New ValueList;
		ButtonsList.Add(DialogReturnCode.Yes, NStr("ru = 'Выгрузить повторно'; en = 'Repeat export'; pl = 'Eksportuj ponownie';es_ES = 'Exportar de nuevo';es_CO = 'Exportar de nuevo';tr = 'Tekrar dışa aktar';it = 'Ripetere l''esportazione';de = 'Exportieren Sie erneut'"));
		ButtonsList.Add(DialogReturnCode.No, NStr("ru = 'Открыть модуль'; en = 'Open module'; pl = 'Otwórz moduł';es_ES = 'Abrir el módulo';es_CO = 'Abrir el módulo';tr = 'Modülü aç';it = 'Aprire modulo';de = 'Modul öffnen'"));
		ButtonsList.Add(DialogReturnCode.Cancel);
		
		NotifyDescription = New NotifyDescription("ExportHandlersCodeCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("ru = 'Модуль отладки с кодом обработчиков уже выгружен.'; en = 'The debug module with the handler script is already exported.'; pl = 'Moduł debugowania z kodem obsługi jest już eksportowany.';es_ES = 'Motor de depuración con el código del manipulador ya se ha exportado.';es_CO = 'Motor de depuración con el código del manipulador ya se ha exportado.';tr = 'İşleyici koduyla hata ayıklama motoru zaten dışa aktarılıyor.';it = 'Il modulo di debug con il codice di elaboratori è già scaricato.';de = 'Die Debug-Engine mit dem Handlercode wurde bereits exportiert.'"), ButtonsList,,DialogReturnCode.No);
		
	Else
		
		ExportHandlersCodeCompletion(DialogReturnCode.Yes, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportHandlersCodeCompletion(Result, AdditionalParameters) Export
	
	HasExportErrors = False;
	
	If Result = DialogReturnCode.Yes Then
		
		ExportedWithErrors = False;
		ExportEventHandlersAtServer(ExportedWithErrors);
		
	ElsIf Result = DialogReturnCode.Cancel Then
		
		Return;
		
	EndIf;
	
	If Not HasExportErrors Then
		
		SetVisibility();
		
		ShowEventHandlersInWindow();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowEventHandlersInWindow()
	
	EventHandlers = EventHandlers();
	If EventHandlers <> Undefined Then
		EventHandlers.Show(NStr("ru = 'Модуль отладки обработчиков'; en = 'Handler debug module'; pl = 'Moduł nastawienia przetwarzania';es_ES = 'Motor de depuración del manipulador';es_CO = 'Motor de depuración del manipulador';tr = 'İşleyici hata ayıklama motoru';it = 'Il modulo di debug di elaboratori';de = 'Handler-Debug-Engine'"));
	EndIf;
	
	
	ExchangeProtocol = ExchangeProtocol();
	If ExchangeProtocol <> Undefined Then
		ExchangeProtocol.Show(NStr("ru = 'Ошибки выгрузки модуля обработчиков'; en = 'Handler debug module export errors'; pl = 'Wystąpił błąd podczas eksportowania modułu obsługi';es_ES = 'Ha ocurrido un error al exportar el módulo del manipulador';es_CO = 'Ha ocurrido un error al exportar el módulo del manipulador';tr = 'İşleyici modülünü dışa aktarırken bir hata oluştu';it = 'Errore di upload del modulo di debug';de = 'Beim Exportieren des Handler-Moduls ist ein Fehler aufgetreten'"));
	EndIf;
	
EndProcedure

&AtServer
Function EventHandlers()
	
	EventHandlers = Undefined;
	
	HandlerFile = New File(Object.EventHandlersTempFileName);
	If HandlerFile.Exist() AND HandlerFile.Size() <> 0 Then
		EventHandlers = New TextDocument;
		EventHandlers.Read(Object.EventHandlersTempFileName);
	EndIf;
	
	Return EventHandlers;
	
EndFunction

&AtServer
Function ExchangeProtocol()
	
	ExchangeProtocol = Undefined;
	
	ErrorLogFile = New File(Object.ExchangeProtocolTempFileName);
	If ErrorLogFile.Exist() AND ErrorLogFile.Size() <> 0 Then
		ExchangeProtocol = New TextDocument;
		ExchangeProtocol.Read(Object.EventHandlersTempFileName);
	EndIf;
	
	Return ExchangeProtocol;
	
EndFunction

&AtServer
Procedure ExportEventHandlersAtServer(Cancel)
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ObjectForServer.ExportEventHandlers(Cancel);
	ValueToFormAttribute(ObjectForServer, "Object");
	
EndProcedure

&AtClient
Procedure OnChangeOfChangeDebugMode()
	
	Tooltip = Items.AlgorithmsDebugTooltip;
	
	Tooltip.CurrentPage = Tooltip.ChildItems["Group_"+Object.AlgorithmDebugMode];
	
EndProcedure

&AtClientAtServerNoContext
Procedure MessageToUser(Text, DataPath = "")
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.DataPath = DataPath;
	Message.Message();
	
EndProcedure

#EndRegion
