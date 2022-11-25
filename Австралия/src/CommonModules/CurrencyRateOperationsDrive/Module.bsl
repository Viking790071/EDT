#Region Private

// Returns an array of currencies whose rates are imported from the 1C website.
//
Function CurrenciesToImport() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSource = VALUE(Enum.RateSources.DownloadFromInternet)
	|	AND NOT Currencies.DeletionMark
	|
	|ORDER BY
	|	Currencies.DescriptionFull";

	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

Procedure CheckAbilityOfUsingExchangeRatesImportProcessor() Export
	
	If CurrenciesToImport().Count() = 0 Then
		Raise NStr("en = 'There are no currencies detected which rates should be imported from the Internet. 
		           |In order to enable rate import for a given currency, please navigate to Cash management - Currencies, 
		           |edit selected currency, then set value ""imported from the Internet"" for option ""Exchange rate"".'; 
		           |ru = 'Не обнаружено валют, которые должны быть загружены из интернета. 
		           |Чтобы включить загрузку для валюты, необходимо зайти в Казначейство - Валюты, 
		           |изменить валюту поставив значение ""загружается из Интернета"" в опции ""Курс валюты"".'; 
		           |pl = 'Nie wykryto żadnych walut, które powinny być importowane z Internetu. 
		           |W celu umożliwienia importu stóp dla danej waluty obcej, przejdź do ""Środki pieniężne"" - ""Waluty"", 
		           |edytuj wybraną walutę, a następnie ustaw wartość ""importowana z Internetu"" dla opcji ""Kurs waluty"".';
		           |es_ES = 'No hay monedas detectadas cuyas tasas tienen que importarse desde Internet. 
		           |Para activar la importación del tipo de cambio para la moneda dada, por favor, navegar a los Fondos - Monedas, 
		           |editar la moneda seleccionada, después establecer el valor ""importado desde Internet"" para la opción ""Tipo de cambio"".';
		           |es_CO = 'No hay monedas detectadas cuyas tasas tienen que importarse desde Internet. 
		           |Para activar la importación del tipo de cambio para la moneda dada, por favor, navegar a los Fondos - Monedas, 
		           |editar la moneda seleccionada, después establecer el valor ""importado desde Internet"" para la opción ""Tipo de cambio"".';
		           |tr = 'Döviz kurlarının internetten içe aktarılması gereken para birimleri bulunamadı.
		           |Belirli bir para birimi için kur aktarımını etkinleştirmek için lütfen Finans - Para birimleri''ne gidin,
		           |seçili para birimini düzenleyin ve ""Döviz kuru"" seçeneği için ""İnternetten içe aktarıldı"" değerini ayarlayın.';
		           |it = 'Non c''è alcuna valuta identificata i cui tassi devono essere importati da internet.
		           |Al fine di abilitare l''importazione tassi per una valuta data, si prega di navigare alla Tesoreria - Valute,
		           |modifica la valuta selezionata, poi impostare ""importato da internet"" per l''opzione ""Tasso di cambio"".';
		           |de = 'Es werden keine Währungen gefunden, welche Tarife aus dem Internet importiert werden sollen.
		           |Um den Kursimport für eine bestimmte Währung zu aktivieren, navigieren Sie zu Barmittelverwaltung- Währungen,
		           |bearbeiten Sie die ausgewählte Währung und setzen Sie dann für die Option ""Wechselkurs"" den Wert ""aus dem Internet importiert"".'");
	EndIf;
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then	
		Raise NStr("en = 'Functional option ""Use additional reports and data processors"" is disabled. 
		           |Enable option in the Settings > Print forms, reports and data processors > Additional reports and data processors'; 
		           |ru = 'Функциональная опция ""Использовать дополнительные отчеты и обработки"" отключена.
		           |Включить опцию можно в разделе Настройки > Печатные формы, отчеты и обработки > Дополнительные отчеты и обработки'; 
		           |pl = 'Opcja funkcjonalna ""Użyj dodatkowych raportów i procesorów danych"" jest wyłączona. 
		           |Włącz opcję w Ustawienia> Formularz wydruku, raporty i procesory danych> Dodatkowe raporty i procesory danych';
		           |es_ES = 'La opción funcional ""Utilizar informes y procesadores de datos adicionales"" está desactivada. 
		           |Habilite la opción en Configuración > Imprimir formularios, informes y procesadores de datos > Informes y procesadores de datos adicionales';
		           |es_CO = 'La opción funcional ""Utilizar informes y procesadores de datos adicionales"" está desactivada. 
		           |Habilite la opción en Configuración > Imprimir formularios, informes y procesadores de datos > Informes y procesadores de datos adicionales';
		           |tr = 'İşlevsel seçenek ""Ek raporlar ve veri işlemcileri kullan"" devre dışı bırakıldı. 
		           |Ayarlar> Formları, raporları ve veri işlemcileri yazdır> Ek raporlar ve veri işlemcileri seçeneğini etkinleştirin';
		           |it = 'L''opzione funzionale ""Utilizza report ed elaboratori dati aggiuntivi"" è disabilitata.
		           |Abilitare l''opzione in Impostazioni->Moduli di stampa, reports ed elaboratori dati->Report e elaboratori dati aggiuntivi';
		           |de = 'Die funktionale Option ""Zusätzliche Berichte und Datenverarbeiter verwenden"" ist deaktiviert.
		           |Aktivieren Sie die Option in den Einstellungen > Druckformulare, Berichte und Datenverarbeiter > Zusätzliche Berichte und Datenverarbeiter'");
	EndIf;
		
EndProcedure

#EndRegion
