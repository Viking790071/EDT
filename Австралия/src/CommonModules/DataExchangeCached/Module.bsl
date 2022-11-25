#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use the new one (see DataExchangeServer.IsOfflineMode).
//
Function IsStandaloneWorkplace() Export
	
	SetPrivilegedMode(True);
	
	If Constants.SubordinateDIBNodeSetupCompleted.Get() Then
		
		Return Constants.IsStandaloneWorkplace.Get();
		
	Else
		
		MasterNodeOfThisInfobase = DataExchangeServer.MasterNode();
		Return MasterNodeOfThisInfobase <> Undefined
			AND IsStandaloneWorkstationNode(MasterNodeOfThisInfobase);
		
	EndIf;
	
EndFunction

// Obsolete. Use the new one (see DataExchangeCached.ExchangePlanNodeByCode).
//
Function FindExchangePlanNodeByCode(ExchangePlanName, NodeCode) Export
	QueryText =
	"SELECT
	|	ExchangePlan.Ref AS Ref
	|FROM
	|	ExchangePlan.[ExchangePlanName] AS ExchangePlan
	|WHERE
	|	ExchangePlan.Code = &Code";
	
	QueryText = StrReplace(QueryText, "[ExchangePlanName]", ExchangePlanName);
	
	Query = New Query;
	Query.SetParameter("Code", NodeCode);
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Return Undefined;
		
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return Selection.Ref;
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Returns a flag that shows whether an exchange plan is used in data exchange.
// If an exchange plan contains at least one node apart from the predefined one, it is considered 
// being used in data exchange.
//
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is set in Designer.
//  Sender - ExchangePlanRef - the parameter value is set if it is necessary to determine whether 
//   there are other exchange nodes besides the one from which the object was received.
//   
//
// Returns:
//  Boolean. True - exchange plan is used, False - not used.
//
Function DataExchangeEnabled(Val ExchangePlanName, Val Sender = Undefined) Export
	
	If Not GetFunctionalOption("UseDataSynchronization") Then
		Return False;
	EndIf;
	
	QueryText = "SELECT TOP 1 1
	|FROM
	|	ExchangePlan." + ExchangePlanName + " AS ExchangePlan
	|WHERE
	|	NOT ExchangePlan.DeletionMark
	|	AND NOT ExchangePlan.ThisNode
	|	AND ExchangePlan.Ref <> &Sender";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Sender", Sender);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// See DataExchangeServer.IsStandaloneWorkstationNode. 
//
Function IsStandaloneWorkstationNode(Val InfobaseNode) Export
	
	Return DataExchangeCached.StandaloneModeSupported()
		AND InfobaseNode.Metadata().Name = DataExchangeCached.StandaloneModeExchangePlan();
	
EndFunction

// See DataExchangeServer.ExchangePlansSettings 
Function ExchangePlanSettings(ExchangePlanName, CorrespondentVersion = "", CorrespondentName = "", CorrespondentInSaaS = Undefined) Export
	Return DataExchangeServer.ExchangePlanSettings(ExchangePlanName, CorrespondentVersion, CorrespondentName, CorrespondentInSaaS);
EndFunction

// See DataExchangeServer.SettingOptionsDetails 
Function SettingOptionDetails(ExchangePlanName, SettingID, 
								CorrespondentVersion = "", CorrespondentName = "") Export
	Return DataExchangeServer.SettingOptionDetails(ExchangePlanName, SettingID, 
								CorrespondentVersion, CorrespondentName);
EndFunction
////////////////////////////////////////////////////////////////////////////////
// The mechanism of object registration on exchange plan nodes (ORM).

// Gets the name of this infobase from a constant or a configuration synonym.
// (For internal use only).
//
Function ThisInfobaseName() Export
	
	SetPrivilegedMode(True);
	
	Result = Constants.SystemTitle.Get();
	
	If IsBlankString(Result) Then
		
		Result = Metadata.Synonym;
		
	EndIf;
	
	Return Result;
EndFunction

// Gets a code of a predefined exchange plan node.
//
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
// 
// Returns:
//  String - a code of a predefined exchange plan node.
//
Function GetThisNodeCodeForExchangePlan(ExchangePlanName) Export
	
	Return Common.ObjectAttributeValue(GetThisExchangePlanNode(ExchangePlanName), "Code");
	
EndFunction

// Gets a name of a predefined exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node.
// 
// Returns:
//  String - name of the predefined exchange plan node.
//
Function ThisNodeDescription(Val InfobaseNode) Export
	
	Return Common.ObjectAttributeValue(GetThisExchangePlanNode(GetExchangePlanName(InfobaseNode)), "Description");
	
EndFunction

// Gets an array of names of configuration exchange plans that use the SSL functionality.
//
// Parameters:
//  No.
// 
// Returns:
// Array - an array of exchange plan name items.
//
Function SSLExchangePlans() Export
	
	Return SSLExchangePlansList().UnloadValues();
	
EndFunction

// Determines whether an exchange plan specified by name is used in SaaS mode.
// For this purpose, all exchange plans on their manager module level define the 
// ExchangePlanUsedInSaaS() function which explicitly returns True or False.
// 
//
// Parameters:
// ExchangePlanName - String.
//
// Returns:
// Boolean.
//
Function ExchangePlanUsedInSaaS(Val ExchangePlanName) Export
	
	Result = False;
	
	If SSLExchangePlans().Find(ExchangePlanName) <> Undefined Then
		Result = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
			"ExchangePlanUsedInSaaS", "");
	EndIf;
	
	Return Result;
	
EndFunction

// Fills in the list of possible error codes.
//
// Returns:
//  Map. Key - error code (number), value - error description (string).
//
Function ErrorMessages() Export
	
	ErrorMessages = New Map;
		
	ErrorMessages.Insert(2,  NStr("ru = 'Ошибка распаковки файла обмена. Файл заблокирован.'; en = 'An error occurred when unpacking an exchange file. The file is locked.'; pl = 'Wystąpił błąd podczas rozpakowywania pliku wymiany. Plik jest zablokowany.';es_ES = 'Ha ocurrido un error al desembalar un archivo de intercambio. El archivo está bloqueado.';es_CO = 'Ha ocurrido un error al desembalar un archivo de intercambio. El archivo está bloqueado.';tr = 'Bir değişim dosyasını paketinden çıkarılırken bir hata oluştu. Dosya kilitli.';it = 'Errore durante la decompressione del file di scambio. Il file è bloccato.';de = 'Beim Entpacken einer Austausch-Datei ist ein Fehler aufgetreten. Die Datei ist gesperrt.'"));
	ErrorMessages.Insert(3,  NStr("ru = 'Указанный файл правил обмена не существует.'; en = 'The specified exchange rule file does not exist.'; pl = 'Określony plik reguły wymiany nie istnieje.';es_ES = 'El archivo de la regla del intercambio especificado no existe.';es_CO = 'El archivo de la regla del intercambio especificado no existe.';tr = 'Belirtilen değişim kuralları dosyası mevcut değil.';it = 'Il file di regole di scambio specificato non esiste.';de = 'Die angegebene Austausch-Regeldatei existiert nicht.'"));
	ErrorMessages.Insert(4,  NStr("ru = 'Ошибка при создании COM-объекта Msxml2.DOMDocument'; en = 'Error creating Msxml2.DOMDocument COM object.'; pl = 'Podczas tworzenia COM obiektu Msxml2.DOMDocument wystąpił błąd';es_ES = 'Ha ocurrido un error al crear el objeto COM Msxml2.DOMDocumento';es_CO = 'Ha ocurrido un error al crear el objeto COM Msxml2.DOMDocumento';tr = 'Msxml2.DOMDocument COM nesnesi oluştururken bir hata oluştu';it = 'Errore durante la creazione dell''oggetto COM Msxml2.DOMDocument.';de = 'Beim Erstellen des COM-Objekts Msxml2.DOMDocument ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(5,  NStr("ru = 'Ошибка открытия файла обмена'; en = 'Error opening exchange file'; pl = 'Podczas otwarcia pliku wymiany wystąpił błąd';es_ES = 'Ha ocurrido un error al abrir el archivo de intercambio';es_CO = 'Ha ocurrido un error al abrir el archivo de intercambio';tr = 'Değişim dosyası açılırken bir hata oluştu';it = 'Errore durante l''apertura del file di scambio';de = 'Beim Öffnen der Austausch-Datei ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(6,  NStr("ru = 'Ошибка при загрузке правил обмена'; en = 'Error importing exchange rules'; pl = 'Podczas importu reguł wymiany wystąpił błąd';es_ES = 'Ha ocurrido un error al importar las reglas de intercambio';es_CO = 'Ha ocurrido un error al importar las reglas de intercambio';tr = 'Değişim kuralları içe aktarılırken bir hata oluştu';it = 'Errore durante il download delle regole di scambio';de = 'Beim Importieren von Austausch-Regeln ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(7,  NStr("ru = 'Ошибка формата правил обмена'; en = 'Exchange rule format error'; pl = 'Błąd formatu reguł wymiany';es_ES = 'Error en el formato de la regla de intercambio';es_CO = 'Error en el formato de la regla de intercambio';tr = 'Değişim kuralı biçiminde hata';it = 'Errore nel formato delle regole di scambio';de = 'Fehler beim Format der Austauschregeln'"));
	ErrorMessages.Insert(8,  NStr("ru = 'Некорректно указано имя файла для выгрузки данных'; en = 'File name for data export is specified incorrectly'; pl = 'Niepoprawnie jest wskazana nazwa pliku do pobierania danych';es_ES = 'Nombre del archivo está indicado incorrectamente para subir los datos';es_CO = 'Nombre del archivo está indicado incorrectamente para subir los datos';tr = 'Veri dışa aktarma için belirtilen dosya adı yanlıştır';it = 'Il nome file per l''esportazione dati è specificato in modo non corretto';de = 'Falscher Dateiname für das Hochladen von Daten'"));
	ErrorMessages.Insert(9,  NStr("ru = 'Ошибка формата файла обмена'; en = 'Exchange file format error'; pl = 'Błąd formatu pliku wymiany';es_ES = 'Error en el formato del archivo de intercambio';es_CO = 'Error en el formato del archivo de intercambio';tr = 'Değişim dosyası biçiminde hata';it = 'Errore formato file di scambio';de = 'Fehler beim Austausch des Dateiformats'"));
	ErrorMessages.Insert(10, NStr("ru = 'Не указано имя файла для выгрузки данных (Имя файла данных)'; en = 'Data export file name is not specified.'; pl = 'Nie określono nazwy pliku do eksportu danych.';es_ES = 'Nombre del archivo para la exportación de datos no está especificado (Nombre del archivo de datos)';es_CO = 'Nombre del archivo para la exportación de datos no está especificado (Nombre del archivo de datos)';tr = 'Veri dışa aktarma için dosya adı belirtilmemiş (Veri dosyasının adı)';it = 'Il nome del file di esportazione dati non è specificato.';de = 'Dateiname für Datenexport ist nicht angegeben (Dateiname)'"));
	ErrorMessages.Insert(11, NStr("ru = 'Ссылка на несуществующий объект метаданных в правилах обмена'; en = 'Exchange rules contain a reference to a nonexistent metadata object'; pl = 'Odwołanie do nieistniejącego obiektu metadanych w regułach wymiany';es_ES = 'Enlace al objeto de metadatos inexistente en las reglas de intercambio';es_CO = 'Enlace al objeto de metadatos inexistente en las reglas de intercambio';tr = 'Değişim kurallarında varolan bir meta veri nesnesine bağlanma';it = 'Il link ad un oggetto di metadati inesistente nelle regole di scambio';de = 'Verknüpfen Sie ein nicht vorhandenes Metadatenobjekt in den Austauschregeln'"));
	ErrorMessages.Insert(12, NStr("ru = 'Не указано имя файла с правилами обмена (Имя файла правил)'; en = 'Exchange rule file name is not specified.'; pl = 'Nie określono nazwy pliku z regułami wymiany.';es_ES = 'Nombre del archivo con las reglas de intercambio no está especificado (Nombre del archivo de la regla)';es_CO = 'Nombre del archivo con las reglas de intercambio no está especificado (Nombre del archivo de la regla)';tr = 'Değişim kuralları ile dosya adı belirtilmemiş (Kural dosyasının adı)';it = 'Non è specificato il nome del file con regole di scambio (Nome file delle regole).';de = 'Dateiname mit Austauschregeln ist nicht angegeben (Regeldateiname)'"));
			
	ErrorMessages.Insert(13, NStr("ru = 'Ошибка получения значения свойства объекта (по имени свойства источника)'; en = 'Error retrieving object property value (by source property name).'; pl = 'Podczas odzyskiwania wartości właściwości obiektu (według nazwy właściwości źródła) wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir un valor de la propiedad del objeto (por el nombre de la propiedad de la fuente)';es_CO = 'Ha ocurrido un error al recibir un valor de la propiedad del objeto (por el nombre de la propiedad de la fuente)';tr = 'Nesne özelliğinin bir değeri alınırken bir hata oluştu (kaynak özelliği adıyla)';it = 'Errore nell''acquisizione del valore di proprietà dell''oggetto (per nome della proprietà di fonte).';de = 'Beim Empfangen eines Werts der Objekteigenschaft (anhand des Namens der Quelleigenschaft) ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(14, NStr("ru = 'Ошибка получения значения свойства объекта (по имени свойства приемника)'; en = 'Error retrieving object property value (by destination property name).'; pl = 'Podczas odzyskiwania wartości właściwości obiektu (według nazwy właściwości celu) wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir el valor de la propiedad del objeto (por el nombre de la propiedad de objetivo)';es_CO = 'Ha ocurrido un error al recibir el valor de la propiedad del objeto (por el nombre de la propiedad de objetivo)';tr = 'Nesne özelliği değerini alınırken bir hata oluştu (hedef özellik adına göre)';it = 'Errore nell''acquisizione del valore di proprietà dell''oggetto (per nome della proprietà di ricevente).';de = 'Fehler beim Abrufen des Objekt-Eigenschaftswerts (nach Ziel-Eigenschaftsname).'"));
	
	ErrorMessages.Insert(15, NStr("ru = 'Не указано имя файла для загрузки данных (Имя файла для загрузки)'; en = 'Import file name is not specified.'; pl = 'Nie określono nazwy pliku do importu danych.';es_ES = 'Nombre del archivo para importación de datos no está especificado (Nombre del archivo para importar)';es_CO = 'Nombre del archivo para importación de datos no está especificado (Nombre del archivo para importar)';tr = 'Veri dışa aktarma için dosya adı belirtilmemiş (İçe aktarılacak dosyasının adı)';it = 'Il nome file di importazione non è specificato.';de = 'Dateiname für den Datenimport ist nicht angegeben (Dateiname für den Import)'"));
			
	ErrorMessages.Insert(16, NStr("ru = 'Ошибка получения значения свойства подчиненного объекта (по имени свойства источника)'; en = 'Error retrieving subordinate object property value (by source property name).'; pl = 'Podczas otrzymywania wartości właściwości obiektu podporządkowanego (według nazwy właściwości źródła) wystąpił błąd.';es_ES = 'Ha ocurrido un error al recibir el valor de la propiedad del subobjeto (por el nombre de la propiedad de la fuente)';es_CO = 'Ha ocurrido un error al recibir el valor de la propiedad del subobjeto (por el nombre de la propiedad de la fuente)';tr = 'Alt nesne özelliğinin değeri alınırken bir hata oluştu (kaynak özellik adına göre)';it = 'Errore nell''acquisizione del valore di proprietà dell''oggetto subordinato (per nome della proprietà di fonte).';de = 'Beim Empfangen des Werts der Unterobjekteigenschaft (nach Name der Quelleigenschaft) ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(17, NStr("ru = 'Ошибка получения значения свойства подчиненного объекта (по имени свойства приемника)'; en = 'Error retrieving subordinate object property value (by destination property name).'; pl = 'Podczas otrzymywania wartości właściwości obiektu podporządkowanego (według nazwy właściwości celu) wystąpił błąd.';es_ES = 'Ha ocurrido un error al recibir el valor de la propiedad del subobjeto (por el nombre de la propiedad de objetivo)';es_CO = 'Ha ocurrido un error al recibir el valor de la propiedad del subobjeto (por el nombre de la propiedad de objetivo)';tr = 'Alt nesne özelliğinin değeri alınırken bir hata oluştu (kaynak özellik adına göre)';it = 'Errore nell''acquisizione del valore di proprietà dell''oggetto subordinato (per nome della proprietà di ricevente).';de = 'Fehler beim Abrufen des Wertes der untergeordneten Objekteigenschaften (nach Name der Zieleigenschaft).'"));
	ErrorMessages.Insert(18, NStr("ru = 'Ошибка при создании обработки с кодом обработчиков'; en = 'Error creating processing with handler script'; pl = 'Wystąpił błąd podczas tworzenia przetwarzania danych z kodem procedury przetwarzania';es_ES = 'Ha ocurrido un error al crear un procesador de datos con el código del manipulador';es_CO = 'Ha ocurrido un error al crear un procesador de datos con el código del manipulador';tr = 'İşleyici koduyla bir veri işlemci oluştururken bir hata oluştu';it = 'Errore durante la creazione dell''elaborazione con script gestore';de = 'Beim Erstellen eines Datenprozessors mit dem Handlercode ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(19, NStr("ru = 'Ошибка в обработчике события BeforeImportObject'; en = 'BeforeImportObject event handler error'; pl = 'Błąd przetwarzania wydarzenia BeforeImportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectImport';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectImport';tr = 'BeforeImportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeImportObject';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler BeforeImportObject'"));
	ErrorMessages.Insert(20, NStr("ru = 'Ошибка в обработчике события OnImportObject'; en = 'OnImportObject event handler error'; pl = 'Błąd przetwarzania wydarzenia OnImportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos OnObjectImport';es_CO = 'Ha ocurrido un error en el manipulador de eventos OnObjectImport';tr = 'OnImportObject veri işleyicisinde bir hata oluştu';it = 'Errore gestore evento OnImportObject';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler OnImportObject'"));
	ErrorMessages.Insert(21, NStr("ru = 'Ошибка в обработчике события AfterImportObject'; en = 'AfterImportObject event handler error'; pl = 'Błąd przetwarzania wydarzenia AfterImportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterObjectImport';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterObjectImport';tr = 'AfterImportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterImportObject';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler AfterImportObject'"));
	ErrorMessages.Insert(22, NStr("ru = 'Ошибка в обработчике события BeforeDataImport (конвертация)'; en = 'BeforeDataImport event handler error (data conversion).'; pl = 'Błąd przetwarzania wydarzenia BeforeDataImport (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeDataImport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeDataImport (conversión)';tr = 'BeforeDataImport olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento BeforeDataImport (conversione dati).';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler BeforeDataImport (Umwandlung)'"));
	ErrorMessages.Insert(23, NStr("ru = 'Ошибка в обработчике события AfterDataImport (конвертация)'; en = 'AfterDataImport event handler error (data conversion).'; pl = 'Błąd przetwarzania wydarzenia AfterDataImport (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterDataImport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterDataImport (conversión)';tr = 'AfterDataImport olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento AfterDataImport (conversione dati).';de = 'Ein Fehler ist aufgetreten in Ereignis-Handler AfterDataImport (Umwandlung)'"));
	ErrorMessages.Insert(24, NStr("ru = 'Ошибка при удалении объекта'; en = 'Error deleting object'; pl = 'Podczas usuwania obiektu wystąpił błąd';es_ES = 'Ha ocurrido un error al eliminar un objeto';es_CO = 'Ha ocurrido un error al eliminar un objeto';tr = 'Nesne silinirken bir hata oluştu';it = 'Errore durante l''eliminazione dell''oggetto';de = 'Beim Entfernen eines Objekts ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(25, NStr("ru = 'Ошибка при записи документа'; en = 'Error writing document'; pl = 'Podczas zapisu dokumentu wystąpił błąd';es_ES = 'Ha ocurrido un error al grabar el documento';es_CO = 'Ha ocurrido un error al grabar el documento';tr = 'Belge yazılırken bir hata oluştu';it = 'Errore durante la registrazione del documento';de = 'Beim Schreiben des Dokuments ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(26, NStr("ru = 'Ошибка записи объекта'; en = 'Error writing object'; pl = 'Podczas zapisu obiektu wystąpił błąd';es_ES = 'Ha ocurrido un error al grabar el objeto';es_CO = 'Ha ocurrido un error al grabar el objeto';tr = 'Nesne yazılırken bir hata oluştu';it = 'Errore durante la scrittura dell''''oggetto';de = 'Beim Schreiben des Objekts ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(27, NStr("ru = 'Ошибка в обработчике события BeforeProcessClearingRule'; en = 'BeforeProcessClearingRule event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeProcessClearingRule';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeProcessClearingRule';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeProcessClearingRule';tr = 'BeforeProcessClearingRule olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeProcessClearingRule';de = 'Im Ereignis-Handler BeforeProcessClearingRule ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(28, NStr("ru = 'Ошибка в обработчике события AfterProcessClearingRule'; en = 'AfterProcessClearingRule event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterProcessClearingRule';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterClearingRuleProcessing';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterClearingRuleProcessing';tr = 'AfterProcessClearingRule olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterProcessClearingRule';de = 'Ein Fehler ist im Ereignis-Handler AfterProcessClearingRule aufgetreten.'"));
	ErrorMessages.Insert(29, NStr("ru = 'Ошибка в обработчике события BeforeDeleteObject'; en = 'BeforeDeleteObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeDeleteObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeDeleteObject';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeDeleteObject';tr = 'BeforeDeleteObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeDeleteObject';de = 'Im Ereignis-Handler BeforeDeleteObject ist ein Fehler aufgetreten'"));
	
	ErrorMessages.Insert(31, NStr("ru = 'Ошибка в обработчике события BeforeProcessExportRule'; en = 'BeforeProcessExportRule event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeProcessExportRule';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeProcessExportRule';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeProcessExportRule';tr = 'BeforeProcessExportRule olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeProcessExportRule';de = 'Im Ereignis-Handler BeforeProcessExportRule ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(32, NStr("ru = 'Ошибка в обработчике события AfterProcessExportRule'; en = 'AfterProcessExportRule event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterProcessExportRule';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterDumpRuleProcessing';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterDumpRuleProcessing';tr = 'AfterProcessExportRule olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterProcessExportRule';de = 'Im Ereignis-Handler AfterProcessExportRule ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(33, NStr("ru = 'Ошибка в обработчике события BeforeExportObject'; en = 'BeforeExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectExport';tr = 'BeforeExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeExportObject';de = 'Im Ereignis-Handler BeforeExportObject ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(34, NStr("ru = 'Ошибка в обработчике события AfterExportObject'; en = 'AfterExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExport';tr = 'AfterExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterExportObject';de = 'Im Ereignis-Handler AfterExportObject ist ein Fehler aufgetreten'"));
			
	ErrorMessages.Insert(41, NStr("ru = 'Ошибка в обработчике события BeforeExportObject'; en = 'BeforeExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeObjectExport';tr = 'BeforeExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento BeforeExportObject';de = 'Im Ereignis-Handler BeforeExportObject ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(42, NStr("ru = 'Ошибка в обработчике события OnExportObject'; en = 'OnExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia OnExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos OnObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos OnObjectExport';tr = 'OnExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento OnExportObject';de = 'Im Ereignis-Handler OnExportObject ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(43, NStr("ru = 'Ошибка в обработчике события AfterExportObject'; en = 'AfterExportObject event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExportObject';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExport';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExport';tr = 'AfterExportObject olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterExportObject';de = 'Im Ereignis-Handler AfterExportObject ist ein Fehler aufgetreten'"));
			
	ErrorMessages.Insert(45, NStr("ru = 'Не найдено правило конвертации объектов'; en = 'No conversion rule is found'; pl = 'Nie znaleziono reguły konwertowania obiektów';es_ES = 'Regla de conversión de objetos no encontrada';es_CO = 'Regla de conversión de objetos no encontrada';tr = 'Nesne dönüştürme kuralı bulunamadı';it = 'Nessuna regola di conversione dell''oggetto trovata';de = 'Die Objektkonvertierungsregel wurde nicht gefunden'"));
		
	ErrorMessages.Insert(48, NStr("ru = 'Ошибка в обработчике события BeforeProcessExport группы свойств'; en = 'BeforeProcessExport property group event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeProcessExport grupy właściwości';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeExportProcessor del grupo de propiedades';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeExportProcessor del grupo de propiedades';tr = 'Özellik grubunun BeforeProcessExport olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento gruppo proprietà BeforeProcessExport';de = 'Im Ereignis-Handler BeforeProcessExport der Eigenschaftsgruppe ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(49, NStr("ru = 'Ошибка в обработчике события AfterProcessExport группы свойств'; en = 'AfterProcessExport property group event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterProcessExport grupy właściwości';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterExportProcessor del grupo de propiedades';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterExportProcessor del grupo de propiedades';tr = 'Özellik grubunun AfterProcessExport olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento gruppo proprietà AfterProcessExport';de = 'Im Ereignis-Handler AfterProcessExport der Eigenschaftsgruppe ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(50, NStr("ru = 'Ошибка в обработчике события BeforeExport (объекта коллекции)'; en = 'BeforeExport event handler error (collection object).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeExport (obiektu kolekcji)';es_ES = 'Error en el manipulador de eventos BeforeExport (del objeto de colección)';es_CO = 'Error en el manipulador de eventos BeforeExport (del objeto de colección)';tr = 'BeforeExport olay işleyicisindeki hata (koleksiyon nesnesinin)';it = 'Errore gestore evento BeforeExport (oggetto raccolta).';de = 'Fehler im Ereignis-Handler BeforeExport (Der Sammlungsobjekt)'"));
	ErrorMessages.Insert(51, NStr("ru = 'Ошибка в обработчике события OnExport (объекта коллекции)'; en = 'OnExport event handler error (collection object).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia OnExport (obiektu kolekcji)';es_ES = 'Error en el manipulador de eventos OnExport (del objeto de colección)';es_CO = 'Error en el manipulador de eventos OnExport (del objeto de colección)';tr = 'OnExport olay işleyicisindeki hata (koleksiyon nesnesinin)';it = 'Errore gestore evento OnExport (oggetto raccolta).';de = 'Fehler im Ereignis-Handler BeimExport (Der Sammlungsobjekt)'"));
	ErrorMessages.Insert(52, NStr("ru = 'Ошибка в обработчике события AfterExport (объекта коллекции)'; en = 'AfterExport event handler error (collection object).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExport (obiektu kolekcji)';es_ES = 'Error en el manipulador de eventos AfterExport (del objeto de colección)';es_CO = 'Error en el manipulador de eventos AfterExport (del objeto de colección)';tr = 'AfterExport olay işleyicisindeki hata (koleksiyon nesnesinin)';it = 'Errore gestore evento AfterExport (oggetto raccolta).';de = 'Fehler im Ereignis-Handler NachDemExport (Der Sammlungsobjekt)'"));
	ErrorMessages.Insert(53, NStr("ru = 'Ошибка в глобальном обработчике события BeforeImportObject (конвертация)'; en = 'BeforeImportObject global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeImportObject (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectImporting (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectImporting (conversión)';tr = 'BeforeImportObject global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale BeforeImportObject (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten VorDemImportierenVonObjekten (Konvertierung)'"));
	ErrorMessages.Insert(54, NStr("ru = 'Ошибка в глобальном обработчике события AfterImportObject (конвертация)'; en = 'AfterImportObject global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterImportObject (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global AfterObjectImport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global AfterObjectImport (conversión)';tr = 'AfterImportObject global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale AfterImportObject (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten NachDemImportierenVonObjekten (Konvertierung)'"));
	ErrorMessages.Insert(55, NStr("ru = 'Ошибка в обработчике события BeforeExport (свойства)'; en = 'BeforeExport event handler error (property).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeExport (właściwości)';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeExport (propiedades)';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeExport (propiedades)';tr = 'BeforeExport olay işleyicisinde bir hata oluştu (özellikler)';it = 'Errore gestore evento BeforeExport (proprietà).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten VorExport (Eigenschaften)'"));
	ErrorMessages.Insert(56, NStr("ru = 'Ошибка в обработчике события OnExport (свойства)'; en = 'OnExport event handler error (property).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia OnExport (właściwości)';es_ES = 'Ha ocurrido un error en el manipulador de eventos OnExport (propiedades)';es_CO = 'Ha ocurrido un error en el manipulador de eventos OnExport (propiedades)';tr = 'OnExport olay işleyicisinde bir hata oluştu (özellikler)';it = 'Errore gestore evento OnExport (proprietà).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten BeimExport (Eigenschaften)'"));
	ErrorMessages.Insert(57, NStr("ru = 'Ошибка в обработчике события AfterExport (свойства)'; en = 'AfterExport event handler error (property).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExport (właściwości)';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterExport (propiedades)';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterExport (propiedades)';tr = 'AfterExport olay işleyicisinde bir hata oluştu (özellikler)';it = 'Errore gestore evento AfterExport (proprietà).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten NachExport (Eigenschaften)'"));
	
	ErrorMessages.Insert(62, NStr("ru = 'Ошибка в обработчике события BeforeDataExport (конвертация)'; en = 'BeforeDataExport event handler error (data conversion).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeDataExport (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeDataExport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeDataExport (conversión)';tr = 'BeforeDataExport olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento BeforeDataExport (conversione dati).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten VorDatenExport (Konvertierung)'"));
	ErrorMessages.Insert(63, NStr("ru = 'Ошибка в обработчике события AfterDataExport (конвертация)'; en = 'AfterDataExport event handler error (data conversion).'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterDataExport (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterDataExport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterDataExport (conversión)';tr = 'AfterDataExport olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento AfterDataExport (conversione dati).';de = 'Im Ereignis-Handler ist ein Fehler aufgetreten NachDatenExport (Konvertierung)'"));
	ErrorMessages.Insert(64, NStr("ru = 'Ошибка в глобальном обработчике события BeforeObjectConversion (конвертация)'; en = 'BeforeObjectConversion global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas globalnego przetwarzania wydarzenia BeforeObjectConversion (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectConversion (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectConversion (conversión)';tr = 'BeforeObjectConversion global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale BeforeObjectConversion (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten VorDerObjektkonvertierung (Konvertierung)'"));
	ErrorMessages.Insert(65, NStr("ru = 'Ошибка в глобальном обработчике события BeforeExportObject (конвертация)'; en = 'BeforeExportObject global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas globalnego przetwarzania wydarzenia BeforeExportObject (konwertowanie)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectExport (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global BeforeObjectExport (conversión)';tr = 'BeforeExportObject global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale BeforeExportObject (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten VorObjektExport (Konvertierung)'"));
	ErrorMessages.Insert(66, NStr("ru = 'Ошибка получения коллекции подчиненных объектов из входящих данных'; en = 'Error retrieving subordinate object collection from incoming data'; pl = 'Podczas otrzymywania kolekcji obiektów podporządkowanych z danych wchodzących wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir una colección de objetos subordinados desde los datos entrantes';es_CO = 'Ha ocurrido un error al recibir una colección de objetos subordinados desde los datos entrantes';tr = 'Gelen verilerden bir alt nesne koleksiyonu alınırken bir hata oluştu';it = 'Errore di acquisizione della raccolta di oggetti subordinati dai dati in arrivo';de = 'Beim Empfang einer untergeordneten Objektsammlung aus den eingehenden Daten ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(67, NStr("ru = 'Ошибка получения свойства подчиненного объекта из входящих данных'; en = 'Error retrieving subordinate object properties from incoming data'; pl = 'Podczas odzyskiwania właściwości obiektu podporządkowanego z danych wchodzących wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir las propiedades del objeto subordinado desde los datos entrantes';es_CO = 'Ha ocurrido un error al recibir las propiedades del objeto subordinado desde los datos entrantes';tr = 'Alt nesne özelliklerini gelen verilerden alırken bir hata oluştu';it = 'Errore di acquisizione della proprietà dell''oggetto subordinato dai dati in arrivo';de = 'Beim Empfang der untergeordneten Objekteigenschaften aus den eingehenden Daten ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(68, NStr("ru = 'Ошибка получения свойства объекта из входящих данных'; en = 'Error retrieving object properties from incoming data'; pl = 'Podczas odzyskiwania właściwości obiektu z danych wchodzących wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir las propiedades del objeto desde los datos entrantes';es_CO = 'Ha ocurrido un error al recibir las propiedades del objeto desde los datos entrantes';tr = 'Nesne özelliklerini gelen verilerden alırken bir hata oluştu';it = 'Errore recuperando le propriteà oggetto dai dati in ingresso';de = 'Beim Empfang der Objekteigenschaften aus den eingehenden Daten ist ein Fehler aufgetreten'"));
	
	ErrorMessages.Insert(69, NStr("ru = 'Ошибка в глобальном обработчике события AfterExportObject конвертация)'; en = 'AfterExportObject global event handler error (data conversion).'; pl = 'Wystąpił błąd podczas globalnego przetwarzania wydarzenia AfterExportObject (konwertowanie)';es_ES = 'Ha ocurrido un error en el manipulador de eventos global AfterObjectExpor (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos global AfterObjectExpor (conversión)';tr = 'AfterExportObject global olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore gestore evento globale AfterExportObject (conversione dati).';de = 'Im globalen Ereignis-Handler ist ein Fehler aufgetreten NachObjektExport (Konvertierung)'"));
	
	ErrorMessages.Insert(71, NStr("ru = 'Не найдено соответствие для значения Источника'; en = 'The map of the Source value is not found'; pl = 'Nie znaleziono odpowiednika dla znaczenia Źródła';es_ES = 'Correspondencia con el valor de la Fuente no encontrada';es_CO = 'Correspondencia con el valor de la Fuente no encontrada';tr = 'Kaynak değerinin eşleşmesi bulunamadı';it = 'La mappa del valore Sorgente non è stato trovato';de = 'Übereinstimmung für den Quellwert wurde nicht gefunden'"));
	
	ErrorMessages.Insert(72, NStr("ru = 'Ошибка при выгрузке данных для узла плана обмена'; en = 'Error exporting data for exchange plan node'; pl = 'Błąd podczas eksportu danych dla węzła planu wymiany';es_ES = 'Ha ocurrido un error al exportar los datos para el nodo del plan de intercambio';es_CO = 'Ha ocurrido un error al exportar los datos para el nodo del plan de intercambio';tr = 'Değişim planı ünitesi için veri dışa aktarılırken bir hata oluştu';it = 'Errore durante l''upload dei dati per il nodo del piano di scambio';de = 'Beim Exportieren von Daten für den Austauschplanknoten ist ein Fehler aufgetreten'"));
	
	ErrorMessages.Insert(73, NStr("ru = 'Ошибка в обработчике события SearchFieldSequence'; en = 'SearchFieldSequence event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia SearchFieldSequence';es_ES = 'Ha ocurrido un error en el manipulador de eventos SearchFieldsSequence';es_CO = 'Ha ocurrido un error en el manipulador de eventos SearchFieldsSequence';tr = 'SearchFieldSequence olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento SearchFieldSequence';de = 'Im Ereignis-Handler SuchfelderSequenz ist ein Fehler aufgetreten'"));
	ErrorMessages.Insert(74, NStr("ru = 'Необходимо перезагрузить правила обмена для выгрузки данных.'; en = 'Exchange rules for data export must be reread.'; pl = 'Należy ponownie wykonać reguły wymiany dla eksportu danych.';es_ES = 'Reglas de intercambio de importación para exportar los datos de nuevo.';es_CO = 'Reglas de intercambio de importación para exportar los datos de nuevo.';tr = 'Veri aktarımı için tekrar değişim kuralları.';it = 'È necessario effettuare nuovamente il download delle regole di scambio per upload dei dati.';de = 'Importieren Sie die Austauschregeln für den Datenexport erneut.'"));
	
	ErrorMessages.Insert(75, NStr("ru = 'Ошибка в обработчике события AfterImportExchangeRules (конвертация)'; en = 'An error occurred in AfterImportExchangeRules event handler (conversion)'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterImportExchangeRules (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterImportOfExchangeRules (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterImportOfExchangeRules (conversión)';tr = 'AfterImportExchangeRules olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Si è verificato un errore nel gestore evento AfterImportExchangeRules (conversione)';de = 'Es ist ein Fehler im Ereignis-Handler AfterImportExchangeRules aufgetreten (Konvertierung)'"));
	ErrorMessages.Insert(76, NStr("ru = 'Ошибка в обработчике события BeforeSendDeletionInformation (конвертация)'; en = 'An error occurred in BeforeSendDeletionInformation event handler (conversion)'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeSendDeletionInformation (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeSendDeletionInformation (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeSendDeletionInformation (conversión)';tr = 'BeforeSendDeletionInformation olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Si è verificato un errore nel gestore evento BeforeSendDeletionInformation (conversione)';de = 'Es ist ein Fehler im BeforeSendDeletionInformation Ereignis-Handler aufgetreten (Konvertierung)'"));
	ErrorMessages.Insert(77, NStr("ru = 'Ошибка в обработчике события OnGetDeletionInformation (конвертация)'; en = 'An error occurred in OnGetDeletionInformation event handler (conversion)'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia OnGetDeletionInformation (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos OnGetDeletionInformation (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos OnGetDeletionInformation (conversión)';tr = 'OnGetDeletionInformation olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Si è verificato un errore nel gestore evento OnGetDeletionInformation (conversione)';de = 'Es ist ein Fehler im OnGetDeletionInformation Ereignis-Handler aufgetreten (Konvertierung)'"));
	
	ErrorMessages.Insert(78, NStr("ru = 'Ошибка при выполнении алгоритма после загрузки значений параметров'; en = 'Error executing algorithm after parameter value import'; pl = 'Podczas wykonania algorytmu po imporcie wartości parametrów wystąpił błąd';es_ES = 'Ha ocurrido un error al ejecutar el algoritmo después de la importación de los valores del parámetro';es_CO = 'Ha ocurrido un error al ejecutar el algoritmo después de la importación de los valores del parámetro';tr = 'Parametre değerlerini içe aktardıktan sonra algoritmayı çalıştırırken bir hata oluştu.';it = 'Errore durante l''esecuzione di algoritmo dopo il download di valori dei parametri';de = 'Beim Ausführen des Algorithmus nach dem Import der Parameterwerte ist ein Fehler aufgetreten'"));
	
	ErrorMessages.Insert(79, NStr("ru = 'Ошибка в обработчике события AfterExportObjectToFile'; en = 'AfterExportObjectToFile event handler error'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterExportObjectToFile';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExportToFile';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterObjectExportToFile';tr = 'AfterExportObjectToFile olay işleyicisinde bir hata oluştu';it = 'Errore gestore evento AfterExportObjectToFile';de = 'Im Ereignis-Handler NachDemObjektExportInDatei ist ein Fehler aufgetreten'"));
	
	ErrorMessages.Insert(80, NStr("ru = 'Ошибка установки свойства предопределенного элемента.
		|Нельзя помечать на удаление предопределенный элемент. Пометка на удаление для объекта не установлена.'; 
		|en = 'An error occurred when setting a predefined item property.
		|Cannot set a deletion mark for a predefined item. The deletion mark is not set for the object.'; 
		|pl = 'Błąd predefiniowanego ustawienia właściwości elementu.
		|Nie można oznaczyć predefiniowanego elementu do usunięcia. Zaznaczenie do usunięcia dla obiektów nie zostało ustawione.';
		|es_ES = 'Error de la configuración de la propiedad del artículo predefinido.
		|Usted no puede marcar el artículo predefinido para borrar. Marca de borrado para los objetos no está instalada.';
		|es_CO = 'Error de la configuración de la propiedad del artículo predefinido.
		|Usted no puede marcar el artículo predefinido para borrar. Marca de borrado para los objetos no está instalada.';
		|tr = 'Önceden tanımlanmış öğe özelliği ayarının hatası. 
		|Önceden silinecek olarak tanımlanmış öğeyi işaretleyemezsiniz. Nesnelerin silinmesi için işaret yüklenmemiş.';
		|it = 'Si è verificato un errore durante l''impostazione della proprietà di un oggetto predefinito.
		|Impossibile impostare un contrassegno di eliminazione per un elemento predefinito. Contrassegno di eliminazione non impostato per l''oggetto.';
		|de = 'Fehler der vordefinierten Einstellung der Elementeigenschaften.
		|Sie können das vordefinierte Element, das gelöscht werden soll, nicht markieren. Die zu löschende Markierung für die Objekte ist nicht installiert.'"));
	//
	ErrorMessages.Insert(81, NStr("ru = 'Возникла коллизия изменений объектов.
		|Объект этой информационной базы был заменен версией объекта из второй информационной базы.'; 
		|en = 'An object change collision occurred.
		|The object from this infobase is replaced with the object version from the second infobase.'; 
		|pl = 'Wystąpił konflikt zmiany obiektu.
		|Ten obiekt bazy informacyjnej został zastąpiony przez drugą wersję obiektu bazy informacyjnej.';
		|es_ES = 'Ha ocurrido la colisión del cambio de objeto.
		|Este objeto de la infobase se ha reemplazado por la versión del objeto de la segunda infobase.';
		|es_CO = 'Ha ocurrido la colisión del cambio de objeto.
		|Este objeto de la infobase se ha reemplazado por la versión del objeto de la segunda infobase.';
		|tr = 'Nesne değişikliği çarpışması meydana geldi. 
		|Bu veritabanı nesnesi, ikinci veritabanı nesne sürümü ile değiştirildi.';
		|it = 'Si è verificato un conflitto durante la modifica all''oggetto.
		|L''oggetto di questa infobase è sostituito con la versione dell''oggetto dalla seconda infobase.';
		|de = 'Die Objektwechselkollision ist aufgetreten.
		|Dieses Infobase-Objekt wurde durch die zweite Infobase-Objektversion ersetzt.'"));
	//
	ErrorMessages.Insert(82, NStr("ru = 'Возникла коллизия изменений объектов.
		|Объект из второй информационной базы не принят. Объект этой информационной базы не изменен.'; 
		|en = 'An object change collision occurred.
		|The object from the second infobase is not accepted. The object from this infobase is not changed.'; 
		|pl = 'Wystąpiła kolizja zmiany obiektu.
		|Obiekt z drugiej bazy informacyjnej nie jest akceptowany. Ten obiekt bazy informacyjnej nie został zmodyfikowany.';
		|es_ES = 'Ha ocurrido la colisión del cambio de objeto.
		|El objeto de la segunda infobase no se ha aceptado. Este objeto de la infobase no se ha modificado.';
		|es_CO = 'Ha ocurrido la colisión del cambio de objeto.
		|El objeto de la segunda infobase no se ha aceptado. Este objeto de la infobase no se ha modificado.';
		|tr = 'Nesne değişiklikleri çakışması ortaya çıktı. 
		|İkinci veritabanındaki nesne kabul edilmedi. Bu veritabanı nesnesi değiştirilmedi.';
		|it = 'Si è verificata un conflitto durante la modifica all''oggetto.
		|L''oggetto della seconda infobase non è stato accettato. L''oggetto di questa infobase non è stato modificato.';
		|de = 'Die Objektwechselkollision ist aufgetreten.
		|Objekt aus der zweiten Infobase wird nicht akzeptiert. Dieses Infobase-Objekt wurde nicht geändert.'"));
	//
	ErrorMessages.Insert(83, NStr("ru = 'Ошибка обращения к табличной части объекта. Табличная часть объекта не может быть изменена.'; en = 'An error occurred while accessing the object tabular section. The object tabular section cannot be changed.'; pl = 'Wystąpił błąd podczas uzyskiwania dostępu do sekcji tabelarycznej obiektu. Nie można zmienić sekcji tabelarycznej obiektu.';es_ES = 'Ha ocurrido un error al acceder a la sección tabular del objeto. La sección tabular del objeto no puede cambiarse.';es_CO = 'Ha ocurrido un error al acceder a la sección tabular del objeto. La sección tabular del objeto no puede cambiarse.';tr = 'Nesne sekme bölümüne erişilirken bir hata oluştu. Nesne sekme bölümü değiştirilemez.';it = 'Si è verificato un errore durante l''accesso alla sezione dell''oggetto tabella. La sezione oggetto tabella non può essere modificato.';de = 'Beim Zugriff auf den Objekttabellenabschnitt ist ein Fehler aufgetreten. Der tabellarische Objektbereich kann nicht geändert werden.'"));
	ErrorMessages.Insert(84, NStr("ru = 'Коллизия дат запрета изменения.'; en = 'Collision of change closing dates.'; pl = 'Konflikt dat zakazu przemiany.';es_ES = 'Colisión de las fechas de cierre de cambios.';es_CO = 'Colisión de las fechas de cierre de cambios.';tr = 'Değişim kapanış tarihlerinin çarpışması.';it = 'Collisione delle date di chiusura cambiamento.';de = 'Kollision der Abschlussdaten der Änderung.'"));
	
	ErrorMessages.Insert(174, NStr("ru = 'Сообщение обмена было принято ранее'; en = 'Exchange message was received earlier'; pl = 'Wiadomość wymiany została przyjęta poprzednio';es_ES = 'Mensaje de intercambio se había recibido previamente';es_CO = 'Mensaje de intercambio se había recibido previamente';tr = 'Değişim iletisi daha önce alındı';it = 'Il messaggio di scambio è stato ricevuto in precedenza';de = 'Austausch-Nachricht wurde zuvor empfangen'"));
	ErrorMessages.Insert(175, NStr("ru = 'Ошибка в обработчике события BeforeGetChangedObjects (конвертация)'; en = 'An error occurred in the BeforeGetChangedObjects event handler (conversion)'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia BeforeGetChangedObjects (konwersja)';es_ES = 'Ha ocurrido un error en el manipulador de eventos BeforeGetChangedObjects (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos BeforeGetChangedObjects (conversión)';tr = 'BeforeGetChangedObjects olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Si è verificato un errore nel gestore evento BeforeGetChangedObjects (conversione)';de = 'Im Ereignis-Handler BeforeGetChangedObjects ist ein Fehler aufgetreten (Konvertierung)'"));
	ErrorMessages.Insert(176, NStr("ru = 'Ошибка в обработчике события AfterReceiveExchangeNodeDetails (конвертация)'; en = 'Error in AfterReceiveExchangeNodeDetails event handler (conversion)'; pl = 'Wystąpił błąd podczas przetwarzania wydarzenia AfterReceiveExchangeNodeDetails (konwertowanie)';es_ES = 'Ha ocurrido un error en el manipulador de eventos AfterGettingInformationAboutExchangeNodes (conversión)';es_CO = 'Ha ocurrido un error en el manipulador de eventos AfterGettingInformationAboutExchangeNodes (conversión)';tr = 'AfterReceiveExchangeNodeDetails olay işleyicisinde bir hata oluştu (dönüştürme)';it = 'Errore nel gestore evento AfterReceiveExchangeNodeDetails (conversione)';de = 'Fehler im AfterReceiveExchangeNodeDetails Ereignis-Handler (Konvertierung)'"));
		
	ErrorMessages.Insert(177, NStr("ru = 'Имя плана обмена из сообщения обмена не соответствует ожидаемому.'; en = 'Exchange plan name from the exchange message is not as expected.'; pl = 'Nazwa planu wymiany w komunikacie wymiany nie jest zgodna z oczekiwaniami.';es_ES = 'Nombre del plan de intercambio del mensaje de intercambio no está tan esperado.';es_CO = 'Nombre del plan de intercambio del mensaje de intercambio no está tan esperado.';tr = 'Değişim mesajındaki değişim planının ismi beklendiği gibi değil.';it = 'Il nome del piano di scambio dal messaggio di scambio non corrisponde a quello previsto.';de = 'Der Name des Austausch-Plans aus der Austausch-Nachricht ist nicht wie erwartet.'"));
	ErrorMessages.Insert(178, NStr("ru = 'Получатель из сообщения обмена не соответствует ожидаемому.'; en = 'Recipient from the exchange message is not as expected.'; pl = 'Odbiorca wiadomości wymiany nie jest zgodny z oczekiwaniami.';es_ES = 'Destinatario del mensaje de intercambio no está tan esperado.';es_CO = 'Destinatario del mensaje de intercambio no está tan esperado.';tr = 'Değişim mesajındaki alıcı beklendiği gibi değil.';it = 'Il destinatario dal messaggio di scambio non corrisponde a quello previsto.';de = 'Empfänger von der Austausch-Nachricht ist nicht wie erwartet.'"));
	
	ErrorMessages.Insert(1000, NStr("ru = 'Ошибка при создании временного файла выгрузки данных'; en = 'Error creating temporary data export file'; pl = 'Wystąpił błąd podczas tworzenia tymczasowego pliku eksportu danych';es_ES = 'Ha ocurrido un error al crear un archivo temporal de la exportación de datos';es_CO = 'Ha ocurrido un error al crear un archivo temporal de la exportación de datos';tr = 'Geçici bir veri aktarımı dosyası oluşturulurken bir hata oluştu';it = 'Errore durante la creazione del file temporaneo di upload dei dati';de = 'Beim Erstellen einer temporären Datei mit Datenexport ist ein Fehler aufgetreten'"));
	
	Return ErrorMessages;
	
EndFunction

Function StandaloneModeSupported() Export
	
	Return StandaloneModeExchangePlans().Count() = 1;
	
EndFunction

Function ExchangePlanPurpose(ExchangePlanName) Export
	
	Return DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "ExchangePlanPurpose");
	
EndFunction

// Determines whether an exchange plan has a template.
//
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is set in Designer.
//  TemplateName - String - a name of the template to check for existence.
// 
//  Returns:
//   True - the exchange plan contains the specified template. Otherwise, False.
//
Function HasExchangePlanTemplate(Val ExchangePlanName, Val TemplateName) Export
	
	Return Metadata.ExchangePlans[ExchangePlanName].Templates.Find(TemplateName) <> Undefined;
	
EndFunction

// Returns the flag showing that the exchange plan belongs to the DIB exchange plan.
//
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is set in Designer.
// 
//  Returns:
//   True if the exchange plan belongs to the DIB exchange plan. Otherwise, False.
//
Function IsDistributedInfobaseExchangePlan(ExchangePlanName) Export
	
	Return Metadata.ExchangePlans[ExchangePlanName].DistributedInfoBase;
	
EndFunction

Function StandaloneModeExchangePlan() Export
	
	Result = StandaloneModeExchangePlans();
	
	If Result.Count() = 0 Then
		
		Raise NStr("ru = 'Автономная работа в системе не предусмотрена.'; en = 'Offline work in the application is not supported.'; pl = 'Praca offline w aplikacji nie jest obsługiwana.';es_ES = 'Trabajo offline en la aplicación no se admite.';es_CO = 'Trabajo offline en la aplicación no se admite.';tr = 'Uygulamada çevrimdışı çalışma desteklenmiyor.';it = 'Lavoro offline nella applicazione non è supportato.';de = 'Offline-Arbeit in der Anwendung wird nicht unterstützt.'");
		
	ElsIf Result.Count() > 1 Then
		
		Raise NStr("ru = 'Создано более одного плана обмена для автономной работы.'; en = 'Multiple exchange plans are created for the standalone mode.'; pl = 'Utworzono więcej niż jeden plan wymiany dla pracy w trybie offline.';es_ES = 'Más de un plan de intercambio para el trabajo offline se ha creado.';es_CO = 'Más de un plan de intercambio para el trabajo offline se ha creado.';tr = 'Çevrimdışı çalışma için birden fazla değişim planı oluşturuldu.';it = 'Sono creati piani multipli di scambio per la modalità stand-alone.';de = 'Mehr als ein Austauschplan für Offline-Arbeiten wurde erstellt.'");
		
	EndIf;
	
	Return Result[0];
EndFunction

// See DataExchangeServer.IsXDTOExchangePlan. 
//
Function IsXDTOExchangePlan(ExchangePlan) Export
	If TypeOf(ExchangePlan) = Type("String") Then
		ExchangePlanName = ExchangePlan;
	Else
		ExchangePlanName = ExchangePlan.Metadata().Name;
	EndIf;
	Return DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "IsXDTOExchangePlan");
EndFunction

Function IsStringAttributeOfUnlimitedLength(FullName, AttributeName) Export
	
	MetadataObject = Metadata.FindByFullName(FullName);
	Attribute = MetadataObject.Attributes.Find(AttributeName);
	
	If Attribute <> Undefined
		AND Attribute.Type.ContainsType(Type("String"))
		AND (Attribute.Type.StringQualifiers.Length = 0) Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// See DataExchangeServer.ExchangePlanNodeByCode. 
//
Function ExchangePlanNodeByCode(ExchangePlanName, NodeCode) Export
	
	Return DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeCode);
	
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// The mechanism of object registration on exchange plan nodes (ORM).

// Retrieves the table of object registration rules for the exchange plan.
//
// Parameters:
//  ExchangePlanName - String - a name of the exchange plan as it is set in Designer for which the 
//                    registration rules are to be received.
// 
// Returns:
// Value table - a table of registration rules for the current exchange plan.
//
Function ExchangePlanObjectsRegistrationRules(Val ExchangePlanName) Export
	
	ObjectsRegistrationRules = DataExchangeServerCall.SessionParametersObjectsRegistrationRules().Get();
	
	Return ObjectsRegistrationRules.Copy(New Structure("ExchangePlanName", ExchangePlanName));
EndFunction

// Gets the table of object registration rules for the specified exchange plan.
//
// Parameters:
//  ExchangePlanName   - String - the exchange plan name as it is set in Designer.
//  FullObjectName - String - a full name of the metadata object for which registration rules are to 
//                   be received.
// 
// Returns:
// Value table - a table of object registration rules for the specified exchange plan.
//
Function ObjectRegistrationRules(Val ExchangePlanName, Val FullObjectName) Export
	
	ExchangePlanObjectsRegistrationRules = DataExchangeEvents.ExchangePlanObjectsRegistrationRules(ExchangePlanName);
	
	Return ExchangePlanObjectsRegistrationRules.Copy(New Structure("MetadataObjectName", FullObjectName));
	
EndFunction

// Returns a flag that shows whether registration rules exist for the object by the specified exchange plan.
//
// Parameters:
//  ExchangePlanName   - String - the exchange plan name as it is set in Designer.
//  FullObjectName - String - a full name of the metadata object whose registration rules must be 
//                   checked for existence.
// 
//  Returns:
//  True if the object registration rules exist, otherwise False.
//
Function ObjectRegistrationRulesExist(Val ExchangePlanName, Val FullObjectName) Export
	
	Return DataExchangeEvents.ObjectRegistrationRules(ExchangePlanName, FullObjectName).Count() <> 0;
	
EndFunction

// Determines whether automatic registration of a metadata object in exchange plan is allowed.
//
// Parameters:
//  ExchangePlanName   - String - a name of the exchange plan as it is set in Designer which 
//                              contains the metadata object.
//  FullObjectName - String - a full name of the metadata object whose automatic registration flag must be checked.
//
//  Returns:
//   True if metadata object automatic registration is allowed in the exchange plan.
//   False if metadata object auto registration is denied in the exchange plan or the exchange plan 
//          does not include the metadata object.
//
Function AutoRegistrationAllowed(Val ExchangePlanName, Val FullObjectName) Export
	
	ExchangePlanCompositionItem = Metadata.ExchangePlans[ExchangePlanName].Content.Find(Metadata.FindByFullName(FullObjectName));
	
	If ExchangePlanCompositionItem = Undefined Then
		Return False; // The exchange plan does not include the metadata object.
	EndIf;
	
	Return ExchangePlanCompositionItem.AutoRecord = AutoChangeRecord.Allow;
EndFunction

// Determines whether the exchange plan includes the metadata object.
//
// Parameters:
//  ExchangePlanName   - String - an exchange plan name as it is set in Designer.
//  FullObjectName - String - a full name of the metadata object whose automatic registration flag is to be checked.
// 
//  Returns:
//   True if the exchange plan includes the object. Otherwise, False.
//
Function ExchangePlanContainsObject(Val ExchangePlanName, Val FullObjectName) Export
	
	ExchangePlanCompositionItem = Metadata.ExchangePlans[ExchangePlanName].Content.Find(Metadata.FindByFullName(FullObjectName));
	
	Return ExchangePlanCompositionItem <> Undefined;
EndFunction

// Returns a list of exchange plans that contain at least one exchange node (ignoring ThisNode).
//
Function ExchangePlansInUse() Export
	
	Return DataExchangeServer.GetExchangePlansInUse();
	
EndFunction

// Returns the exchange plan content specified by the user.
// Custom exchange plan content is determined by the object registration rules and node settings 
// specified by the user.
//
// Parameters:
//  Recipient - ExchangePlanRef - an exchange plan node reference. User content is retrieved for 
//               this node.
//
//  Returns:
//   Map:
//     * Key     - String - a full name of a metadata object that is included in the exchange plan content.
//     * Value - EnumRef.ExchangeObjectExportModes - object export mode.
//
Function UserExchangePlanComposition(Val Recipient) Export
	
	SetPrivilegedMode(True);
	
	Result = New Map;
	
	DestinationProperties = Common.ObjectAttributesValues(Recipient,
		Common.AttributeNamesByType(Recipient, Type("EnumRef.ExchangeObjectExportModes")));
	
	Priorities = ObjectsExportModesPriorities();
	ExchangePlanName = Recipient.Metadata().Name;
	Rules = DataExchangeCached.ExchangePlanObjectsRegistrationRules(ExchangePlanName);
	Rules.Indexes.Add("MetadataObjectName");
	
	For Each Item In Metadata.ExchangePlans[ExchangePlanName].Content Do
		
		ObjectName = Item.Metadata.FullName();
		ObjectRules = Rules.FindRows(New Structure("MetadataObjectName", ObjectName));
		ExportMode = Undefined;
		
		If ObjectRules.Count() = 0 Then // Registration rules are not set.
			
			ExportMode = Enums.ExchangeObjectExportModes.ExportAlways;
			
		Else // Registration rules are set.
			
			For Each ORR In ObjectRules Do
				
				If ValueIsFilled(ORR.FlagAttributeName) Then
					ExportMode = ObjectExportMaxMode(DestinationProperties[ORR.FlagAttributeName], ExportMode, Priorities);
				EndIf;
				
			EndDo;
			
			If ExportMode = Undefined
				OR ExportMode = Enums.ExchangeObjectExportModes.EmptyRef() Then
				ExportMode = Enums.ExchangeObjectExportModes.ExportByCondition;
			EndIf;
			
		EndIf;
		
		Result.Insert(ObjectName, ExportMode);
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return Result;
EndFunction

// Returns the object export mode based on the custom exchange plan content (user settings).
//
// Parameters:
//  ObjectName - a metadata object full name. Export mode is retrieved for this metadata object.
//  Recipient - ExchangePlanRef - an exchange plan node reference. The function gets custom content from this node.
//
// Returns:
//   EnumRef.ExchangeObjectExportModes -  object export mode.
//
Function ObjectExportMode(Val ObjectName, Val Recipient) Export
	
	Result = DataExchangeCached.UserExchangePlanComposition(Recipient).Get(ObjectName);
	
	Return ?(Result = Undefined, Enums.ExchangeObjectExportModes.ExportAlways, Result);
EndFunction

Function ObjectExportMaxMode(Val ExportMode1, Val ExportMode2, Val Priorities)
	
	If Priorities.Find(ExportMode1) < Priorities.Find(ExportMode2) Then
		
		Return ExportMode1;
		
	Else
		
		Return ExportMode2;
		
	EndIf;
	
EndFunction

Function ObjectsExportModesPriorities()
	
	Result = New Array;
	Result.Add(Enums.ExchangeObjectExportModes.ExportAlways);
	Result.Add(Enums.ExchangeObjectExportModes.ManualExport);
	Result.Add(Enums.ExchangeObjectExportModes.ExportByCondition);
	Result.Add(Enums.ExchangeObjectExportModes.EmptyRef());
	Result.Add(Enums.ExchangeObjectExportModes.ExportIfNecessary);
	Result.Add(Enums.ExchangeObjectExportModes.DoNotExport);
	Result.Add(Undefined);
	
	Return Result;
EndFunction

// Retrieves the table of object registration attributes for the mechanism of selective object registration.
//
// Parameters:
//  ObjectName     - String - a full metadata object name, for example, "Catalog.Products".
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
//
// Returns:
//  RegistrationAttributesTable - value table - a table of registration attributes ordered by the 
//  Order field for the specified metadata object.
//
Function ObjectAttributesToRegister(ObjectName, ExchangePlanName) Export
	
	ObjectsRegistrationAttributesTable = DataExchangeServer.GetSelectiveObjectsRegistrationRulesSP();
	
	Filter = New Structure;
	Filter.Insert("ExchangePlanName", ExchangePlanName);
	Filter.Insert("ObjectName",     ObjectName);
	
	RegistrationAttributesTable = ObjectsRegistrationAttributesTable.Copy(Filter);
	
	RegistrationAttributesTable.Sort("Order Asc");
	
	Return RegistrationAttributesTable;
	
EndFunction

// Gets the table of selective object registration from session parameters.
//
// Parameters:
// No.
// 
// Returns:
// Value table - a table of registration attributes for all metadata objects.
//
Function GetSelectiveObjectsRegistrationRulesSP() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.SelectiveObjectsRegistrationRules.Get();
	
EndFunction

// Gets a predefined exchange plan node.
//
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
// 
// Returns:
//  ThisNode - ExchangePlanRef - a predefined exchange plan node.
//
Function GetThisExchangePlanNode(ExchangePlanName) Export
	
	Return ExchangePlans[ExchangePlanName].ThisNode();
	
EndFunction

// Returns the flag showing whether the node belongs to DIB exchange plan.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node that requires receiving the function value.
// 
//  Returns:
//   True - the node belongs to DIB exchange plan. Otherwise, False.
//
Function IsDistributedInfobaseNode(Val InfobaseNode) Export

	Return InfobaseNode.Metadata().DistributedInfoBase;
	
EndFunction

// Returns the flag showing that the node belongs to a standard exchange plan (without conversion rules).
//
// Parameters:
//  ExchangePlanName - String - a name of the exchange plan which requires the function value.
// 
//  Returns:
//   True if the node belongs to the standard exchange plan. Otherwise, False.
//
Function IsStandardDataExchangeNode(ExchangePlanName) Export
	
	If DataExchangeServer.IsXDTOExchangePlan(ExchangePlanName) Then
		Return False;
	EndIf;
	
	Return Not DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName)
		AND Not DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "ExchangeRules");
	
EndFunction

// Returns the flag showing whether the node belongs to a universal exchange plan (using conversion rules).
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node that requires receiving the function value.
// 
//  Returns:
//   True if the node belongs to the universal exchange plan. Otherwise, False.
//
Function IsUniversalDataExchangeNode(InfobaseNode) Export
	
	If DataExchangeServer.IsXDTOExchangePlan(InfobaseNode) Then
		Return True;
	Else
		Return Not IsDistributedInfobaseNode(InfobaseNode)
			AND HasExchangePlanTemplate(GetExchangePlanName(InfobaseNode), "ExchangeRules");
	EndIf;
	
EndFunction

// Returns the flag showing whether the node belongs to an exchange plan that uses SSL exchange functionality.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef, ExchangePlanObject - an exchange plan node for which the 
//                           function value is to be received.
// 
//  Returns:
//   True if the node belongs to the exchange plan that uses SSL exchange functionality. Otherwise, False.
//
Function IsSSLDataExchangeNode(Val InfobaseNode) Export
	
	Return SSLExchangePlans().Find(GetExchangePlanName(InfobaseNode)) <> Undefined;
	
EndFunction

// Returns the flag showing whether the node belongs to a separated exchange plan that uses SSL exchange functionality.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node that requires receiving the function value.
// 
//  Returns:
//   True if the node belongs to the separated exchange plan that uses SSL exchange functionality. Otherwise, False.
//
Function IsSeparatedSSLDataExchangeNode(InfobaseNode) Export
	
	Return SeparatedSSLExchangePlans().Find(GetExchangePlanName(InfobaseNode)) <> Undefined;
	
EndFunction

// Returns the flag showing whether the node belongs to the exchange plan used for message exchange.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node that requires receiving the function value.
// 
//  Returns:
//   True if the node belongs to the message exchange plan. Otherwise, False.
//
Function IsMessagesExchangeNode(InfobaseNode) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		Return False;
	EndIf;
	
	Return DataExchangeCached.GetExchangePlanName(InfobaseNode) = "MessageExchange";
	
EndFunction

// Gets a name of the exchange plan as a metadata object for the specified node.
//
// Parameters:
//  ExchangePlanNode - ExchangePlanRef - an exchange plan node.
// 
// Returns:
//  Name - String - a name of the exchange plan as a metadata object.
//
Function GetExchangePlanName(ExchangePlanNode) Export
	
	Return ExchangePlanNode.Metadata().Name;
	
EndFunction

// Gets a list of templates of standard exchange rules from configuration for the specified exchange plan.
// The list contains names and synonyms of the rule templates.
// 
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
// 
// Returns:
//  RulesList - a value list - a list of templates of standard exchange rules.
//
Function ConversionRulesForExchangePlanFromConfiguration(ExchangePlanName) Export
	
	Return RulesForExchangePlanFromConfiguration(ExchangePlanName, "ExchangeRules");
	
EndFunction

// Gets a list of templates of standard registration rules from configuration for the specified exchange plan.
// The list contains names and synonyms of the rule templates.
//
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
// 
// Returns:
//  RulesList - a value list - a list of templates of standard registration rules.
//
Function RegistrationRulesForExchangePlanFromConfiguration(ExchangePlanName) Export
	
	Return RulesForExchangePlanFromConfiguration(ExchangePlanName, "RecordRules");
	
EndFunction

// Gets a list of configuration exchange plans that use the SSL functionality.
// The list is filled with names and synonyms of exchange plans.
//
// Parameters:
//  No.
// 
// Returns:
//  ExchangePlansList - value list - a list of configuration exchange plans.
//
Function SSLExchangePlansList() Export
	
	// Function return value.
	ExchangePlanList = New ValueList;
	
	SubsystemExchangePlans = New Array;
	
	DataExchangeOverridable.GetExchangePlans(SubsystemExchangePlans);
	
	For Each ExchangePlan In SubsystemExchangePlans Do
		
		ExchangePlanList.Add(ExchangePlan.Name, ExchangePlan.Synonym);
		
	EndDo;
	
	Return ExchangePlanList;
	
EndFunction

// Gets an array of names of separated configuration exchange plans that use the SSL functionality.
// If the configuration does not contain separators, all exchange plans are treated as separated.
//
// Parameters:
//  No.
// 
// Returns:
// Array - an array of elements of separated exchange plan names.
//
Function SeparatedSSLExchangePlans() Export
	
	Result = New Array;
	
	For Each ExchangePlanName In SSLExchangePlans() Do
		
		If Common.SubsystemExists("StandardSubsystems.SaaS") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			IsSeparatedConfiguration = ModuleSaaS.IsSeparatedConfiguration();
		Else
			IsSeparatedConfiguration = False;
		EndIf;
		
		If IsSeparatedConfiguration Then
			
			If ModuleSaaS.IsSeparatedMetadataObject("ExchangePlan." + ExchangePlanName,
					ModuleSaaS.MainDataSeparator()) Then
				
				Result.Add(ExchangePlanName);
				
			EndIf;
			
		Else
			
			Result.Add(ExchangePlanName);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// For internal use.
//
Function CommonNodeData(Val InfobaseNode) Export
	
	Return DataExchangeServer.CommonNodeData(GetExchangePlanName(InfobaseNode),
		InformationRegisters.CommonInfobasesNodesSettings.CorrespondentVersion(InfobaseNode),
		"");
EndFunction

// For internal use.
//
Function ExchangePlanTabularSections(Val ExchangePlanName, Val CorrespondentVersion = "", Val SettingID = "") Export
	
	CommonTables             = New Array;
	ThisInfobaseTables          = New Array;
	AllTablesOfThisInfobase       = New Array;
	
	CommonNodeData = DataExchangeServer.CommonNodeData(ExchangePlanName, CorrespondentVersion, SettingID);
	
	TabularSections = DataExchangeEvents.ObjectTabularSections(Metadata.ExchangePlans[ExchangePlanName]);
	
	If Not IsBlankString(CommonNodeData) Then
		
		For Each TabularSection In TabularSections Do
			
			If StrFind(CommonNodeData, TabularSection) <> 0 Then
				
				CommonTables.Add(TabularSection);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	ThisInfobaseSettings = DataExchangeServer.NodeFilterStructure(ExchangePlanName, CorrespondentVersion, SettingID);
	
	ThisInfobaseSettings = DataExchangeEvents.StructureKeysToString(ThisInfobaseSettings);
	
	If IsBlankString(CommonNodeData) Then
		
		For Each TabularSection In TabularSections Do
			
			AllTablesOfThisInfobase.Add(TabularSection);
			
			If StrFind(ThisInfobaseSettings, TabularSection) <> 0 Then
				
				ThisInfobaseTables.Add(TabularSection);
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TabularSection In TabularSections Do
			
			AllTablesOfThisInfobase.Add(TabularSection);
			
			If StrFind(ThisInfobaseSettings, TabularSection) <> 0 Then
				
				If StrFind(CommonNodeData, TabularSection) = 0 Then
					
					ThisInfobaseTables.Add(TabularSection);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("CommonTables",             CommonTables);
	Result.Insert("ThisInfobaseTables",          ThisInfobaseTables);
	Result.Insert("AllTablesOfThisInfobase",       AllTablesOfThisInfobase);
	
	Return Result;
	
EndFunction

// Gets the exchange plan manager by exchange plan name.
//
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
//
// Returns:
//  ExchangePlanManager - an exchange plan manager.
//
Function GetExchangePlanManagerByName(ExchangePlanName) Export
	
	Return ExchangePlans[ExchangePlanName];
	
EndFunction

// Gets the exchange plan manager by name of the exchange plan metadata object.
//
// Parameters:
//  ExchangePlanNode - ExchangePlanRef - an exchange plan node for which you need to get a manager.
// 
Function GetExchangePlanManager(ExchangePlanNode) Export
	
	Return GetExchangePlanManagerByName(GetExchangePlanName(ExchangePlanNode));
	
EndFunction

// Wrapper of the function with the same name.
//
Function ConfigurationMetadata(Filter) Export
	
	For Each FilterItem In Filter Do
		
		Filter[FilterItem.Key] = StrSplit(FilterItem.Value, ",");
		
	EndDo;
	
	Return DataExchangeServer.ConfigurationMetadataTree(Filter);
	
EndFunction

// For internal use.
//
Function ExchangeSettingsStructureForInteractiveImportSession(InfobaseNode, ExchangeMessageFileName) Export
	
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsForInfobaseNode(
		InfobaseNode,
		Enums.ActionsOnExchange.DataImport,
		Undefined,
		False);
		
	ExchangeSettingsStructure.DataExchangeDataProcessor.ExchangeFileName = ExchangeMessageFileName;
	
	Return ExchangeSettingsStructure;
	
EndFunction

// Wrapper of the function with the same name from the DataExchangeEvents module.
//
Function NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, FlagAttributeName, Val DataExported = False) Export
	
	#If ExternalConnection OR ThickClientOrdinaryApplication Then
		
		Return DataExchangeServerCall.NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, FlagAttributeName, DataExported);
		
	#Else
		
		SetPrivilegedMode(True);
		Return DataExchangeEvents.NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, FlagAttributeName, DataExported);
		
	#EndIf
	
EndFunction

// Returns a collection of exchange message transports that can be used for the specified exchange plan node.
//
// Parameters:
//  InfobaseNode - ExchangePlanRef - an exchange plan node that requires receiving the function value.
//  SetupOption       - String           - ID of data synchronization setup option.
// 
//  Returns:
//   Array - message transports that are used for the specified exchange plan node.
//
Function UsedExchangeMessagesTransports(InfobaseNode, Val SetupOption = "") Export
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	If Not InfobaseNode.IsEmpty() Then
		SetupOption = DataExchangeServer.SavedExchangePlanNodeSettingOption(InfobaseNode);
	EndIf;
	
	SettingOptionDetails = DataExchangeCached.SettingOptionDetails(ExchangePlanName,  
		SetupOption, "", "");
	
	Result = SettingOptionDetails.UsedExchangeMessagesTransports;
	
	If Result.Count() = 0 Then
		Result = DataExchangeServer.AllConfigurationExchangeMessagesTransports();
	EndIf;
	
	// Exchange via COM connection is not supported:
	//  - For basic configuration versions.
	//  - For DIB.
	//  - For standard exchange (without conversion rules).
	//  - For 1C servers under Linux.
	//
	If StandardSubsystemsServer.IsBaseConfigurationVersion()
		Or DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName)
		Or DataExchangeCached.IsStandardDataExchangeNode(ExchangePlanName)
		Or Common.IsLinuxServer() Then
		
		CommonClientServer.DeleteValueFromArray(Result,
			Enums.ExchangeMessagesTransportTypes.COM);
			
	EndIf;
	
	// Exchange via WS connection is not supported:
	//  - For DIB that are not SWP.
	//
	If DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName)
		AND Not DataExchangeCached.IsStandaloneWorkstationNode(InfobaseNode) Then
		
		CommonClientServer.DeleteValueFromArray(Result,
			Enums.ExchangeMessagesTransportTypes.WS);
		
	EndIf;
	
	// Exchange via WS connection in passive mode is not supported:
	//  - For objects that are not an exchange through XDTO.
	//  - For file infobases.
	//
	If Not DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName)
		Or Common.FileInfobase() Then
		
		CommonClientServer.DeleteValueFromArray(Result,
			Enums.ExchangeMessagesTransportTypes.WSPassiveMode);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Establishes an external connection to the infobase and returns a reference to this connection.
// 
// Parameters:
//  InfobaseNode (required) - ExchangePlanRef. Exchange plan node for which the external connection 
//  is required.
//  ErrorMessageString (optional) - String - if an error occurs when establishing an external connection,
// the detailed description of the error is written to this parameter.
//
// Returns:
//  COMObject - if external connection is established. Undefined - if external connection is not established.
//
Function GetExternalConnectionForInfobaseNode(InfobaseNode, ErrorMessageString = "") Export

	Result = ExternalConnectionForInfobaseNode(InfobaseNode);

	ErrorMessageString = Result.DetailedErrorDescription;
	Return Result.Connection;
	
EndFunction

// Establishes an external connection to the infobase and returns a reference to this connection.
// 
// Parameters:
//  InfobaseNode (required) - ExchangePlanRef. Exchange plan node for which the external connection 
//  is required.
//  ErrorMessageString (optional) - String - if an error occurs when establishing an external connection,
// the detailed description of the error is written to this parameter.
//
// Returns:
//  COMObject - if external connection is established. Undefined - if external connection is not established.
//
Function ExternalConnectionForInfobaseNode(InfobaseNode) Export
	
	Return DataExchangeServer.EstablishExternalConnectionWithInfobase(
        InformationRegisters.DataExchangeTransportSettings.TransportSettings(
            InfobaseNode, Enums.ExchangeMessagesTransportTypes.COM));
	
EndFunction

// Determines whether the exchange plan can be used.
// The flag is calculated by the configuration functional options composition.
// If no functional option includes the exchange plan, the function returns True.
// If functional options include the exchange plan and one or more functional option is enabled, the 
// function returns True.
// Otherwise, the function returns False.
//
// Parameters:
//  ExchangePlanName - String. Name of the exchange plan to get the flag for.
//
// Returns:
//  True - the exchange plan can be used.
//  False - it cannot be used.
//
Function ExchangePlanUsageAvailable(Val ExchangePlanName) Export
	
	ObjectIsIncludedInFunctionalOptions = False;
	
	For Each FunctionalOption In Metadata.FunctionalOptions Do
		
		If FunctionalOption.Content.Contains(Metadata.ExchangePlans[ExchangePlanName]) Then
			
			ObjectIsIncludedInFunctionalOptions = True;
			
			If GetFunctionalOption(FunctionalOption.Name) = True Then
				
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If Not ObjectIsIncludedInFunctionalOptions Then
		
		Return True;
		
	EndIf;
	
	Return False;
EndFunction

// Returns an array of version numbers supported by correspondent API for the DataExchange subsystem.
// 
// Parameters:
// Correspondent - Structure, ExchangePlanRef. Exchange plan node that corresponds the correspondent 
//                 infobase.
//
// Returns:
// Array of version numbers that are supported by correspondent API.
//
Function CorrespondentVersions(Val Correspondent) Export
	
	If TypeOf(Correspondent) = Type("Structure") Then
		SettingsStructure = Correspondent;
	Else
		If DataExchangeCached.IsMessagesExchangeNode(Correspondent) Then
			ModuleMessagesExchangeTransportSettings = InformationRegisters["MessageExchangeTransportSettings"];
			SettingsStructure = ModuleMessagesExchangeTransportSettings.TransportSettingsWS(Correspondent);
		Else
			SettingsStructure = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(Correspondent);
		EndIf;
	EndIf;
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSWebServiceURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUsername);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return Common.GetInterfaceVersions(ConnectionParameters, "DataExchange");
	
EndFunction

// Returns the array of all reference types available in the configuration.
//
Function AllConfigurationReferenceTypes() Export
	
	Result = New Array;
	
	CommonClientServer.SupplementArray(Result, Catalogs.AllRefsType().Types());
	CommonClientServer.SupplementArray(Result, Documents.AllRefsType().Types());
	CommonClientServer.SupplementArray(Result, BusinessProcesses.AllRefsType().Types());
	CommonClientServer.SupplementArray(Result, ChartsOfCharacteristicTypes.AllRefsType().Types());
	CommonClientServer.SupplementArray(Result, ChartsOfAccounts.AllRefsType().Types());
	CommonClientServer.SupplementArray(Result, ChartsOfCalculationTypes.AllRefsType().Types());
	CommonClientServer.SupplementArray(Result, Tasks.AllRefsType().Types());
	CommonClientServer.SupplementArray(Result, ExchangePlans.AllRefsType().Types());
	CommonClientServer.SupplementArray(Result, Enums.AllRefsType().Types());
	
	Return Result;
EndFunction

Function StandaloneModeExchangePlans()
	
	// An exchange plan that is used to implement the standalone mode in SaaS mode must meet the following conditions:
	// - must be separated.
	// - must be a DIB exchange plan.
	// - be used for exchange in SaaS (ExchangePlanUsedInSaaS = True).
	
	Result = New Array;
	
	For Each ExchangePlan In Metadata.ExchangePlans Do
		
		If DataExchangeServer.IsSeparatedSSLExchangePlan(ExchangePlan.Name)
			AND ExchangePlan.DistributedInfoBase
			AND DataExchangeCached.ExchangePlanUsedInSaaS(ExchangePlan.Name) Then
			
			Result.Add(ExchangePlan.Name);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function SecurityProfileName(Val ExchangePlanName) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Return Undefined;
	EndIf;
	
	If Catalogs.MetadataObjectIDs.IsDataUpdated() Then
		ExchangePlanID = Common.MetadataObjectID(Metadata.ExchangePlans[ExchangePlanName]);
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		SecurityProfileName = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(ExchangePlanID);
	Else
		SecurityProfileName = Undefined;
	EndIf;
	
	If SecurityProfileName = Undefined Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		SecurityProfileName = ModuleSafeModeManager.InfobaseSecurityProfile();
		If IsBlankString(SecurityProfileName) Then
			SecurityProfileName = Undefined;
		EndIf;
	EndIf;
	
	Return SecurityProfileName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initialization of the data exchange settings structure.

// Initializes the data exchange subsystem to execute the exchange process.
//
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - a structure with all necessary data and objects to execute exchange.
//
Function ExchangeSettingsOfInfobaseNode(
	InfobaseNode,
	ActionOnExchange,
	ExchangeMessagesTransportKind,
	UseTransportSettings = True) Export
	
	Return DataExchangeServer.ExchangeSettingsForInfobaseNode(
		InfobaseNode,
		ActionOnExchange,
		ExchangeMessagesTransportKind,
		UseTransportSettings);
EndFunction

// Initializes the data exchange subsystem to execute the exchange process.
//
// Parameters:
// 
// Returns:
//  ExchangeSettingsStructure - Structure - a structure with all necessary data and objects to execute exchange.
//
Function DataExchangeSettings(ExchangeExecutionSettings, RowNumber) Export
	
	Return DataExchangeServer.DataExchangeSettings(ExchangeExecutionSettings, RowNumber);
	
EndFunction

// Gets the transport settings structure for data exchange.
//
Function TransportSettingsOfExchangePlanNode(InfobaseNode, ExchangeMessagesTransportKind) Export
	
	Return DataExchangeServer.ExchangeTransportSettings(InfobaseNode, ExchangeMessagesTransportKind);
	
EndFunction

// Gets a list of templates of standard rules for data exchange from configuration for the specified exchange plan.
// The list contains names and synonyms of the rule templates.
// 
// Parameters:
//  ExchangePlanName - String - an exchange plan name as it is specified in Designer.
// 
// Returns:
//  RulesList - a value list - a list of templates of standard rules for data exchange.
//
Function RulesForExchangePlanFromConfiguration(ExchangePlanName, TemplateNameLiteral)
	
	RulesList = New ValueList;
	
	If IsBlankString(ExchangePlanName) Then
		Return RulesList;
	EndIf;
	
	For Each Template In Metadata.ExchangePlans[ExchangePlanName].Templates Do
		
		If StrFind(Template.Name, TemplateNameLiteral) <> 0 AND StrFind(Template.Name, "Correspondent") = 0 Then
			
			RulesList.Add(Template.Name, Template.Synonym);
			
		EndIf;
		
	EndDo;
	
	Return RulesList;
EndFunction

// Returns a node content table (reference types only).
//
// Parameters:
//    ExchangePlanName - String - an exchange plan to analyze.
//    Periodic - a flag that shows whether objects with date (such as documents) are included in the result.
//    Regulatory - a flag that shows whether regulatory data objects are included in the result.
//
// Returns:
//    ValueTable - a table with the following columns:
//      * FullMetadataName - String - a full metadata name (a table name for the query).
//      * ListPresentation - String - list presentation for a table.
//      * Presentation       - String - object presentation for a table.
//      * PictureIndex      - Number - a picture index according to PictureLib.MetadataObjectsCollection.
//      * Type                 - Type - the corresponding type.
//      * SelectPeriod        - Boolean - a flag showing that filter by period can be applied to the object.
//
Function ExchangePlanContent(ExchangePlanName, Periodic = True, Regulatory = True) Export
	
	ResultTable = New ValueTable;
	For Each KeyValue In (New Structure("FullMetadataName, Presentation, ListPresentation, PictureIndex, Type, SelectPeriod")) Do
		ResultTable.Columns.Add(KeyValue.Key);
	EndDo;
	For Each KeyValue In (New Structure("FullMetadataName, Presentation, ListPresentation, Type")) Do
		ResultTable.Indexes.Add(KeyValue.Key);
	EndDo;
	
	ExchangePlanComposition = Metadata.ExchangePlans.Find(ExchangePlanName).Content;
	For Each CompositionItem In ExchangePlanComposition Do
		
		ObjectMetadata = CompositionItem.Metadata;
		Details = MetadataObjectDetails(ObjectMetadata);
		If Details.PictureIndex >= 0 Then
			If Not Periodic AND Details.Periodic Then 
				Continue;
			ElsIf Not Regulatory AND Details.Reference Then 
				Continue;
			EndIf;
			
			Row = ResultTable.Add();
			FillPropertyValues(Row, Details);
			Row.SelectPeriod        = Details.Periodic;
			Row.FullMetadataName = ObjectMetadata.FullName();
			Row.ListPresentation = DataExchangeServer.ObjectListPresentation(ObjectMetadata);
			Row.Presentation       = DataExchangeServer.ObjectPresentation(ObjectMetadata);
		EndIf;
	EndDo;
	
	ResultTable.Sort("ListPresentation");
	Return ResultTable;
	
EndFunction

Function MetadataObjectDetails(Meta)
	
	Result = New Structure("PictureIndex, Periodic, Reference, Type", -1, False, False);
	
	If Metadata.Catalogs.Contains(Meta) Then
		Result.PictureIndex = 3;
		Result.Reference = True;
		Result.Type = Type("CatalogRef." + Meta.Name);
		
	ElsIf Metadata.Documents.Contains(Meta) Then
		Result.PictureIndex = 7;
		Result.Periodic = True;
		Result.Type = Type("DocumentRef." + Meta.Name);
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(Meta) Then
		Result.PictureIndex = 9;
		Result.Reference = True;
		Result.Type = Type("ChartOfCharacteristicTypesRef." + Meta.Name);
		
	ElsIf Metadata.ChartsOfAccounts.Contains(Meta) Then
		Result.PictureIndex = 11;
		Result.Reference = True;
		Result.Type = Type("ChartOfAccountsRef." + Meta.Name);
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(Meta) Then
		Result.PictureIndex = 13;
		Result.Reference = True;
		Result.Type = Type("ChartOfCalculationTypesRef." + Meta.Name);
		
	ElsIf Metadata.BusinessProcesses.Contains(Meta) Then
		Result.PictureIndex = 23;
		Result.Periodic = True;
		Result.Type = Type("BusinessProcessRef." + Meta.Name);
		
	ElsIf Metadata.Tasks.Contains(Meta) Then
		Result.PictureIndex = 25;
		Result.Periodic  = True;
		Result.Type = Type("TaskRef." + Meta.Name);
		
	EndIf;
	
	Return Result;
EndFunction

// It determines whether versioning is used.
//
// Parameters:
//	Sender - ExchangePlanRef - determines whether object version creating is needed for the passed 
//		node if the parameter is passed.
//
Function VersioningUsed(Sender = Undefined, CheckAccessRights = False) Export
	
	Used = False;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		
		Used = ?(Sender <> Undefined, IsSSLDataExchangeNode(Sender), True);
		
		If Used AND CheckAccessRights Then
			
			ModuleObjectVersioning = Common.CommonModule("ObjectsVersioning");
			Used = ModuleObjectVersioning.HasRightToReadObjectVersionInfo();
			
		EndIf;
			
	EndIf;
	
	Return Used;
	
EndFunction

// Returns the name of the temporary file directory.
//
// Returns:
//	String - a path to the temporary file directory.
//
Function TempFilesStorageDirectory() Export
	
	// If the current infobase is running in file mode, the function returns TempFilesDir.
	If Common.FileInfobase() Then 
		Return TrimAll(TempFilesDir());
	EndIf;
	
	CommonPlatformType = "Windows";
	
	SystemInfo = New SystemInfo;
	ServerPlatformType = SystemInfo.PlatformType;
	
	SetPrivilegedMode(True);
	
	If    ServerPlatformType = PlatformType.Windows_x86
		OR ServerPlatformType = PlatformType.Windows_x86_64 Then
		
		Result         = Constants.DataExchangeMessageDirectoryForWindows.Get();
		
	ElsIf ServerPlatformType = PlatformType.Linux_x86
		OR   ServerPlatformType = PlatformType.Linux_x86_64 Then
		
		Result         = Constants.DataExchangeMessageDirectoryForLinux.Get();
		CommonPlatformType = "Linux";
		
	Else
		
		Result         = Constants.DataExchangeMessageDirectoryForWindows.Get();
		
	EndIf;
	
	SetPrivilegedMode(False);
	
	ConstantPresentation = ?(CommonPlatformType = "Linux", 
		Metadata.Constants.DataExchangeMessageDirectoryForLinux.Presentation(),
		Metadata.Constants.DataExchangeMessageDirectoryForWindows.Presentation());
	
	If IsBlankString(Result) Then
		
		Result = TrimAll(TempFilesDir());
		
	Else
		
		Result = TrimAll(Result);
		
		// Checking whether the directory exists.
		Directory = New File(Result);
		If Not Directory.Exist() Then
			
			MessageTemplate = NStr("ru = 'Каталог временных файлов не существует.
					|Необходимо убедиться, что в настройках программы задано правильное значение параметра
					|""%1"".'; 
					|en = 'No temporary file directory.
					|Make sure the value of parameter
					|""%1"" was correctly set in the application settings.'; 
					|pl = 'Katalog tymczasowych plików nie istnieje.
					|Należy upewnić się, że w ustawieniach programu jest podana prawidłowa wartość parametrów
					|""%1"".';
					|es_ES = 'El catálogo de archivos temporales no existe.
					|Es necesario asegurarse de que en los ajustes del programa está establecido un valor correcto del parámetro
					|""%1"".';
					|es_CO = 'El catálogo de archivos temporales no existe.
					|Es necesario asegurarse de que en los ajustes del programa está establecido un valor correcto del parámetro
					|""%1"".';
					|tr = 'Geçici dosya dizini mevcut değil. 
					|Uygulama ayarlarında 
					| ""%1"" parametre değerinin doğru belirtildiğinden emin olunmalıdır.';
					|it = 'Nessuna directory di file temporanei.
					|Accertarsi che il valore del parametro
					|""%1"" sia impostato correttamente nelle impostazioni di applicazione.';
					|de = 'Es gibt kein Verzeichnis für temporäre Dateien.
					|Es ist darauf zu achten, dass in den Programmeinstellungen der richtige Wert des Parameters
					|""%1"" eingestellt ist.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, ConstantPresentation);
			Raise(MessageText);
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
