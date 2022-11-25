#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("FirstLaunchPassed")
		And Not Parameters.FirstLaunchPassed Then
		
		UpdateConfigurationPackage = False;
		
	ElsIf Parameters.Property("UpdateConfigurationPackage")
		And Parameters.UpdateConfigurationPackage Then
		
		UpdateConfigurationPackage = True;
		
		CustomizationRegion = Constants.CustomizationRegion.Get();
		If ValueIsFilled(CustomizationRegion) Then
			Country = CustomizationRegion;
		Else
			Country = "Default";
		EndIf;
	EndIf;
	
	SystemVersion = Metadata.Version;
	ConfigurationName = Metadata.Name;
	
	PathToConfigurationPackage = "";
	
	FirstLaunchInfo = Constants.FirstLaunchInfo.Get().Get();
	If TypeOf(FirstLaunchInfo) = Type("Structure") Then
		
		ExtensionsLoaded = FirstLaunchInfo.ExtensionsLoaded;
		PathToConfigurationPackage = FirstLaunchInfo.PathToConfigurationPackage;
		Country = FirstLaunchInfo.Country;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ExtensionsLoaded Then
		
		Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
		Folder = PathToCountryFolder(Country);
		AttachIdleHandler("Attachable_FillPredefinedData", 0.2, True);
		
	Else
		
		If Not ValueIsFilled(PathToConfigurationPackage) Then
			SetPathToConfigurationPackage();
		EndIf;
		
		If UpdateConfigurationPackage Then
			AttachIdleHandler("Attachable_LoadConfigurationData", 0.2, True);
		Else
			AttachIdleHandler("Attachable_FillCountries", 0.2, True);
		EndIf;
	
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not InitialSetupDone Then
		
		StandardProcessing	= False;
		Cancel				= True;
		
		WarningText = NStr("en = 'Initial configuration setup is a mandatory step and cannot be omitted.'; ru = 'Начальная настройка конфигурации - это обязательный этап, который не может быть пропущен.';pl = 'Wstępne ustawienie konfiguracji – to krok obowiązkowy i nie można go pominąć.';es_ES = 'Ajuste de la configuración inicial es un paso obligatorio y no puede ser omitido.';es_CO = 'Ajuste de la configuración inicial es un paso obligatorio y no puede ser omitido.';tr = 'İlk yapılandırma ayarları zorunlu bir adımdır ve atlanamaz.';it = 'Impostazione della configurazione iniziale è un passaggio obbligatorio e non può essere omesso.';de = 'Die Erstkonfiguration ist ein obligatorischer Schritt und kann nicht weggelassen werden.'");
		
		If Exit Then
			Return;
		EndIf;
			
		Buttons = New ValueList;
		Buttons.Add("Exit", NStr("en = 'Exit'; ru = 'Завершить';pl = 'Zakończ';es_ES = 'Salir';es_CO = 'Salir';tr = 'Çıkış';it = 'Uscita';de = 'Ausgang'"));
		Buttons.Add("Cancel", NStr("en = 'Cancel'; ru = 'Отмена';pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
				
		Notification = New NotifyDescription("ConfirmFormClosingEnd", ThisObject, Parameters);
		ShowQueryBox(Notification, WarningText, Buttons,, "Cancel");
		
	Else
		
		If ShowKitProcessingInfobaseUpdate() Then
			
			StandardProcessing	= False;
			Cancel				= True;
			OpenKitProcessingInfobaseUpdate();
			
		EndIf;
		
		If ShowMappingGLAccountsToIncomeAndExpenseItems() Then
			
			StandardProcessing	= False;
			Cancel				= True;
			OpenMappingGLAccountsToIncomeAndExpenseItems();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "KitProcessingInfobaseUpdateClosing" Then
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationLoadURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	LoadFromCustomFile();
EndProcedure

&AtClient
Procedure PathToConfigurationPackageStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	LoadFromCustomFile();
EndProcedure

&AtClient
Procedure CountryOnChange(Item)
	RefreshFormData();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CancelBackgroundJob(Command)
	CancelBackgroundJobAtServer(JobID);
	SetCurrentPage();
EndProcedure

&AtClient
Procedure OK(Command)
	
	If LanguageIsChanged Then
		Terminate(True, "/C ""StartInfobaseUpdate; DisableUpdateConfigurationPackage""");
	ElsIf UserWasCreated Then
		Terminate(True);
	Else
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure Proceed(Command)
	
	If Items.GroupPages.CurrentPage = Items.GroupHomePage Then
		
		If Country = "" Then 
			CommonClientServer.MessageToUser(
				NStr("en = 'Choose your country'; ru = 'Выберите страну';pl = 'Wybierz swój kraj';es_ES = 'Seleccionar su país';es_CO = 'Seleccionar su país';tr = 'Ülkeyi seçin';it = 'Scegli il tuo paese';de = 'Wählen Sie Ihr Land'")
					,
					,
					"Country");
		Else
			Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
			AttachIdleHandler("Attachable_FillPredefinedData", 0.2, True);
		EndIf;
		
	ElsIf Items.GroupPages.CurrentPage = Items.GroupChooseConfigurationPackageManually Then
		
		If PathToConfigurationPackage = "" Then 
			CommonClientServer.MessageToUser(
				NStr("en = 'Choose your configuration file'; ru = 'Выберите файл конфигурации';pl = 'Wybierz swój plik konfiguracyjny';es_ES = 'Seleccionar su archivo de configuración';es_CO = 'Seleccionar su archivo de configuración';tr = 'Yapılandırma dosyanızı seçin';it = 'Scegli il tuo file di configurazione';de = 'Wählen Sie Ihre Konfigurationsdatei'"));
		Else
			Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
			If UpdateConfigurationPackage Then
				AttachIdleHandler("Attachable_LoadConfigurationData", 0.2, True);
			Else
				AttachIdleHandler("Attachable_FillCountries", 0.2, True);
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SeeEventLog(Command)
	OpenForm("DataProcessor.EventLog.Form");
EndProcedure

#EndRegion

#Region Private

#Region AttachableAndNotifyProceduresAndFunctions

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		JobCompleted = JobCompleted(JobID);
	Except
		
		SetCurrentPage();
		
		ErrorInfo = BriefErrorDescription(ErrorInfo());
		ShowErrorMessageToUser(ErrorInfo);
		
		Return;
	EndTry;
	
	If JobCompleted Then
		AfterJobComplete();
	Else
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", IdleHandlerParameters.CurrentInterval, True);
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_FillCountries()
	
	If ValueIsFilled(PathToConfigurationPackage) Then
		
		File = New File(PathToConfigurationPackage);
		If File.Exist() Then
			StorageAddress = PutToTempStorage(New BinaryData(PathToConfigurationPackage));
			LoadCountriesFromFirstLaunch(StorageAddress);
		Else
			SetDefaultCountry();
		EndIf;
	Else
		SetDefaultCountry();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_LoadConfigurationData()
	
	ConfigurationPackage = New File(PathToConfigurationPackage);
	
	If Upper(Country) = "DEFAULT" Then
		AttachIdleHandler("Attachable_FillPredefinedData", 0.2, True);
	ElsIf ConfigurationPackage.Exist() Then
		Folder = PathToCountryFolder(Country);
		If ValueIsFilled(Folder) Then
			AttachIdleHandler("Attachable_FillPredefinedData", 0.2, True);
		Else
			AttachIdleHandler("Attachable_FillCountries", 0.2, True);
		EndIf;
		Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
	Else
		SetPathToConfigurationPackageManually();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_FillPredefinedData()
	
	If ValueIsFilled(PathToConfigurationPackage) Then
		
		File = New File(PathToConfigurationPackage);
		If File.Exist() Then
			StorageAddress = PutToTempStorage(New BinaryData(PathToConfigurationPackage));
		Else
			SetPathToConfigurationPackageManually();
		EndIf;
	Else
		StorageAddress = Undefined;
	EndIf;
	
	If Not ExtensionsLoaded Then
		
		LoadExtensionsFromFiles(StorageAddress);
		
		If ExtensionsLoaded Then
			
			SaveFirstLaunchInfo();
			Terminate(True);
			
		EndIf;
		
	EndIf;
	
	If Not AnErrorOnLoadingExtensions Then
		
		Result = FillPredefinedDataInBackground(StorageAddress);
		AfterBackgroundJobStarts(Result);
		
	EndIf;
	
EndProcedure

&AtServer
Function FillPredefinedDataInBackground(StorageAddress)
	
	If Upper(Country) = "DEFAULT" Then
		
		LanguageIsChanged = False;
		ProcedureParameters = New Structure();
		ProcedureParameters.Insert("UpdateConfigurationPackage", UpdateConfigurationPackage);
		ProcedureParameters.Insert("FullPath", "default");
		ProcedureName = "InfobaseUpdateDrive.ExecuteFillByDefault";
		JobDescription = NStr("en = 'First launch - fill by default is in a progress'; ru = 'Первоначальное заполнение - выполняется заполнение по умолчанию';pl = 'Pierwsze uruchomienie – domyślnie wypełnienie jest w toku';es_ES = 'Primer lanzamiento - relleno por defecto está en progreso';es_CO = 'Primer lanzamiento - relleno por defecto está en progreso';tr = 'İlk başlatma - varsayılan olarak doldurma devam ediyor';it = 'Primo avvio - Il compilamento predefinito è in esecuzione';de = 'Erster Start - Füllung standardmäßig ist in einem Fortschritt'");
		
	Else
		
		Folder = PathToCountryFolder(Country);
		ProcedureParameters = New Structure();
		ProcedureParameters.Insert("FullPath", Folder);
		ProcedureParameters.Insert("ZIP", GetFromTempStorage(StorageAddress));
		ProcedureParameters.Insert("UpdateConfigurationPackage", UpdateConfigurationPackage);
		ProcedureParameters.Insert("LanguageIsChanged", LanguageIsChanged);
		ProcedureName = "InfobaseUpdateDrive.ExecuteFillPredefinedData";
		JobDescription = NStr("en = 'First launch - fill predefined data from file is in a progress'; ru = 'Первоначальное заполнение - выполняется заполнение предопределенными данными из файла';pl = 'Pierwsze uruchomienie – wypełnienie predefiniowanych danych z pliku jest w toku';es_ES = 'Primer lanzamiento - relleno de los datos predefinidos desde el archivo está en progreso';es_CO = 'Primer lanzamiento - relleno de los datos predefinidos desde el archivo está en progreso';tr = 'İlk başlatma - dosyadan önceden tanımlanmış verileri doldurma devam ediyor';it = 'Primo avvio - Il compilamento predefinito  da un file è in esecuzione';de = 'Erster Start - Füllung vordefinierter Daten ist in einem Fortschritt'");
		
	EndIf;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = JobDescription;
	
	Return TimeConsumingOperations.ExecuteInBackground(ProcedureName, ProcedureParameters, ExecutionParameters);
	
EndFunction

&AtClient
Procedure ConfirmFormClosingEnd(Response, Parameters) Export
	
	If Response = "Exit" Then
		Terminate();
	EndIf;
	
EndProcedure

#EndRegion

#Region BackgroundJobsHandlers

&AtClient
Procedure AfterBackgroundJobStarts(Result)
	
	JobID				= Result.JobID;
	JobStorageAddress	= Result.ResultAddress;
	
	If Result.Status = "Completed" Then
		AfterJobComplete();
	Else
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterJobComplete()
	
	JobResult = GetFromTempStorage(JobStorageAddress);
	
	If JobResult.Done Then
		
		If JobResult.Property("Countries") Then
			
			FillCountriesAtServer(JobResult.Countries);
			
			Items.GroupPages.CurrentPage = Items.GroupHomePage;
		
		Else
			InitialSetupDone = JobResult.Done;
			If InitialSetupDone Then
				
				LanguageIsChanged = JobResult.LanguageIsChanged;
				UserWasCreated = JobResult.UserWasCreated;
				
				If LanguageIsChanged
					Or UserWasCreated Then
					Items.DecorationSuccessText.Title = NStr("en = 'Configuration setup has been completed successfully. 
					                                         |1C:Drive must be restarted for changes to take effect.'; 
					                                         |ru = 'Первоначальное заполнение прошло успешно.
					                                         |Необходимо перезапустить 1C:Drive для того, чтобы изменения вступили в силу.';
					                                         |pl = 'Konfiguracja początkowa została pomyślnie zakończona. 
					                                         |1C:Drive musi zostać zrestartowany, aby zmiany zaczęły obowiązywać.';
					                                         |es_ES = 'Ajuste de la configuración se ha finalizado con éxito. 
					                                         |1C:Drive tiene que reiniciarse para que los cambios entren en vigor.';
					                                         |es_CO = 'Ajuste de la configuración se ha finalizado con éxito. 
					                                         |1C:Drive tiene que reiniciarse para que los cambios entren en vigor.';
					                                         |tr = 'Yapılandırma ayarları başarıyla tamamlandı. 
					                                         |Değişikliklerin uygulanması için 1C:Drive yeniden başlatılmalıdır.';
					                                         |it = 'L''impostazione della configurazione è stato effettuato con successo.
					                                         |1C:Drive deve essere riavviato perchè i cambiamenti abbiano effetto.';
					                                         |de = 'Die Konfiguration wurde erfolgreich abgeschlossen.
					                                         |1C:Drive muss neu gestartet werden, damit Änderungen wirksam werden.'");
					Items.OK.Title = NStr("en = 'Restart'; ru = 'Повторный запуск';pl = 'Uruchom ponownie';es_ES = 'Reiniciar';es_CO = 'Reiniciar';tr = 'Yeniden başlat';it = 'Ricominciare';de = 'Neustart'");
				EndIf;
				Items.GroupPages.CurrentPage = Items.GroupFinishPage;
				Items.PagesStatus.CurrentPage = Items.PageSucces;
				UpdateServiceData(Country);
			Else
				Items.GroupPages.CurrentPage = Items.GroupHomePage;
			EndIf;
		EndIf;
	Else
		ShowErrorMessageToUser(JobResult.ErrorMessage);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CancelBackgroundJobAtServer(JobID)
	TimeConsumingOperations.CancelJobExecution(JobID);
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	Return TimeConsumingOperations.JobCompleted(JobID);
EndFunction

#EndRegion

#Region ConfigurationPackage

&AtClient
Procedure SetPathToConfigurationPackage()
	
	If CommonClientServer.IsWindowsClient()
		And Not CommonClientServer.IsWebClient() Then
		
		Shell = New COMObject("WScript.Shell");
		APPDATAFolder = Shell.ExpandEnvironmentStrings("%APPDATA%");
		
		Template = "\1c\%1\%2\ConfigurationPackage\first_launch.zip";
		PathPart = StringFunctionsClientServer.SubstituteParametersToString(
			Template,
			ConfigurationName,
			StrReplace(SystemVersion, ".", "_"));
		
		TmpltsFolder1 = APPDATAFolder + "\1C\1cv8\tmplts";
		TmpltsFolder2 = APPDATAFolder + "\1C\1c8\tmplts";
		
		File = New File(TmpltsFolder1);
		If File.Exist() Then
			PathToConfigurationPackage = TmpltsFolder1 + PathPart;
		Else
			PathToConfigurationPackage = TmpltsFolder2 + PathPart;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDefaultCountry()
	
	DetachIdleHandler("Attachable_FillCountries");
	
	Country = "Default";
	PathToConfigurationPackage = "";
	
	Items.Country.ChoiceList.Add("Default", NStr("en = 'Initialize with default settings'; ru = 'Заполнить данными по умолчанию';pl = 'Zainicjuj z domyślnymi ustawieniami';es_ES = 'Iniciar con las configuraciones por defecto';es_CO = 'Iniciar con las configuraciones por defecto';tr = 'Varsayılan ayarlarla başlat';it = 'Avviamento con le impostazioni predefinite';de = 'Initialisieren mit Standardeinstellungen'"));
	Items.GroupPages.CurrentPage = Items.GroupHomePage;
	
EndProcedure

&AtClient
Procedure LoadCountriesFromFirstLaunch(StorageAddress)
	
	Result = FillCountriesInBackground(StorageAddress);
	AfterBackgroundJobStarts(Result);
	
EndProcedure

#EndRegion

#Region Extensions

&AtServer
Procedure LoadExtensionsFromFiles(StorageAddress)
	
	If Upper(Country) <> "DEFAULT" Then
		
		ZIPData = GetFromTempStorage(StorageAddress);
		
		ProcedureParameters = New Structure();
		ProcedureParameters.Insert("FullPath", Folder);
		ProcedureParameters.Insert("ZIP", ZIPData);
		ProcedureParameters.Insert("UpdateConfigurationPackage", UpdateConfigurationPackage);
		ProcedureParameters.Insert("LanguageIsChanged", LanguageIsChanged);
		
		StorageAddress = PutToTempStorage(ZIPData);
		
		Try
			
			ResultStructure = InfobaseUpdateDrive.LoadExtensionsFromFiles(ProcedureParameters);
			If ResultStructure.Done Then
				
				CommonClientServer.MessageToUser(
				NStr("en = 'Configuration extensions applied successfully'; ru = 'Расширения конфигурации применены успешно';pl = 'Rozszerzenia konfiguracji zostały pomyślnie zastosowane';es_ES = 'Extensiones de configuración aplicadas con éxito';es_CO = 'Extensiones de configuración aplicadas con éxito';tr = 'Yapılandırma uzantıları başarıyla uygulandı';it = 'Configurazione delle estensioni applicata con successo';de = 'Konfigurationserweiterungen erfolgreich angewendet'"));
				
				ExtensionsLoaded = True;
				
			ElsIf Not IsBlankString(ResultStructure.ErrorMessage) Then
				
				Items.GroupPages.CurrentPage = Items.GroupHomePage;
				CommonClientServer.MessageToUser(ResultStructure.ErrorMessage);
				
				AnErrorOnLoadingExtensions = True;
				
			EndIf;
			
		Except
			
			Items.GroupPages.CurrentPage = Items.GroupHomePage;
			CommonClientServer.MessageToUser(ErrorDescription());
			AnErrorOnLoadingExtensions = True;
			
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FirstLaunchInfo

&AtServerNoContext
Procedure ClearFirstLaunchInfo()
	
	FirstLaunchInfoEmptyValue = New ValueStorage(FirstLaunchInfoEmptyStructure());
	Constants.FirstLaunchInfo.Set(FirstLaunchInfoEmptyValue);
	
EndProcedure

&AtServer
Procedure SaveFirstLaunchInfo()
	
	FirstLaunchInfo = FirstLaunchInfoEmptyStructure();
	FirstLaunchInfo.ExtensionsLoaded = ExtensionsLoaded;
	FirstLaunchInfo.PathToConfigurationPackage = PathToConfigurationPackage;
	FirstLaunchInfo.Country = Country;
	
	Constants.FirstLaunchInfo.Set(New ValueStorage(FirstLaunchInfo));
	
EndProcedure

&AtServerNoContext
Function FirstLaunchInfoEmptyStructure()
	
	Result = New Structure;
	Result.Insert("ExtensionsLoaded", False);
	Result.Insert("PathToConfigurationPackage", "");
	Result.Insert("Country", "Default");
	
	Return Result;
	
EndFunction

#EndRegion

#Region LongActions

&AtServer
Function FillCountriesInBackground(StorageAddress)
	
	ProcedureParameters = New Structure("ZIP, Countries", GetFromTempStorage(StorageAddress), Countries.Unload());
	ProcedureName = "InfobaseUpdateDrive.ExecuteLoadCountriesFromFirstLaunch";
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'First launch - countries from ZIP file loading is in a progress'; ru = 'Первоначальное заполнение - выполняется загрузка стран из ZIP файла';pl = 'Pierwsze uruchomienie – trwa importowanie krajów z pliku ZIP';es_ES = 'Primer lanzamiento - carga de los países del archivo ZIP está en progreso';es_CO = 'Primer lanzamiento - carga de los países del archivo ZIP está en progreso';tr = 'İlk başlatma - ZIP dosyasından ülkelerin yüklenmesi devam ediyor';it = 'Primo avvio - caricamento Paesi da un file ZIP in esecuzione';de = 'Erster Start - Länder von ZIP-Datei laden ist in einem Fortschritt'");
	
	Return TimeConsumingOperations.ExecuteInBackground(ProcedureName, ProcedureParameters, ExecutionParameters);
EndFunction

&AtServerNoContext
Procedure UpdateServiceData(Country)
	
	If ValueIsFilled(Country) Then
		FolderName = PathToCountryFolder(Country);
		Constants.CustomizationRegion.Set(FolderName);
	EndIf;
	
	Constants.UpdateConfigurationPackage.Set(False);
	Constants.FirstLaunchPassed.Set(True);
	ClearFirstLaunchInfo();
	
EndProcedure

&AtServer
Procedure FillCountriesAtServer(CountriesArray)
	
	Countries.Clear();
	
	For Each Row In CountriesArray Do
		NewRow = Countries.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	
	ArrayOfCountries = Countries.Unload().UnloadColumn("Name");
	Items.Country.ChoiceList.LoadValues(ArrayOfCountries);
	Items.Country.ChoiceList.Add("Default", NStr("en = 'Initialize with default settings'; ru = 'Заполнить данными по умолчанию';pl = 'Zainicjuj z domyślnymi ustawieniami';es_ES = 'Iniciar con las configuraciones por defecto';es_CO = 'Iniciar con las configuraciones por defecto';tr = 'Varsayılan ayarlarla başlat';it = 'Avviamento con le impostazioni predefinite';de = 'Initialisieren mit Standardeinstellungen'"));
	
	If ArrayOfCountries.Count() = 1 Then
		
		Country = ArrayOfCountries[0];
		
		Rows = Countries.FindRows(New Structure("Name", Country));
		If Rows.Count() = 0 Then
			Return;
		EndIf;
		
		Description = Rows[0].Description;
		Folder		= Rows[0].Folder;

	ElsIf ArrayOfCountries.Count() = 0 Then
		Country = "Default";
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PathToCountryFolder(Country)
	PathToCountryFolder = StrReplace(Lower(Country), " ","_");
	Return PathToCountryFolder;
EndFunction

#EndRegion

#Region FormItems

&AtClient
Procedure SetPathToConfigurationPackageManually()
	
	PathToConfigurationPackage = "";
	Items.GroupPages.CurrentPage = Items.GroupChooseConfigurationPackageManually;
	
EndProcedure

&AtClient
Procedure SetCurrentPage()
	
	If JobName = "ExecuteUpdateExtensions" Then
		Items.GroupPages.CurrentPage = Items.GroupChooseConfigurationPackageManually;
	Else
		Items.GroupPages.CurrentPage = Items.GroupHomePage;
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshFormData()
	
	Rows = Countries.FindRows(New Structure("Name", Country));
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	Description = Rows[0].Description;
	Folder		= Rows[0].Folder;
	
EndProcedure

&AtClient
Procedure ShowErrorMessageToUser(Text)
	
	Items.GroupPages.CurrentPage = Items.GroupFinishPage;
	Items.PagesStatus.CurrentPage = Items.PageError;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occured during initial configuration setup.
			     |Contact your partner and provide him following information: %1'; 
			     |ru = 'Произошла ошибка во время начальной настройки конфигурации.
			     |Свяжитесь со своим партнером и предоставьте ему следующую информацию: %1';
			     |pl = 'Wystąpił błąd podczas początkowego ustawienia konfiguracji.
			     |Skontaktuj się ze swoim partnerem i podaj mu następujące informacje: %1';
			     |es_ES = 'Ha ocurrido un error durante el ajuste de la configuración inicial.
			     |Contactar su colaborador y proporcionarle la siguiente información: %1';
			     |es_CO = 'Ha ocurrido un error durante el ajuste de la configuración inicial.
			     |Contactar su colaborador y proporcionarle la siguiente información: %1';
			     |tr = 'İlk yapılandırma ayarları sırasında bir hata oluştu. 
			     |Ortağınızla iletişime geçin ve ona aşağıdaki bilgileri verin:%1';
			     |it = 'Si è verificato un errore durante l''installazione iniziale della configurazione. 
			     |Contattare il proprio partner e fornirgli le seguenti informazioni: %1';
			     |de = 'Bei der Erstkonfiguration ist ein Fehler aufgetreten.
			     |Kontaktieren Sie Ihren Partner und geben Sie ihm folgende Informationen: %1'"),
			Text);
	
EndProcedure

#EndRegion

#Region LoadFromFile

&AtClient
Procedure LoadFromCustomFile()
	
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Title = NStr("en = 'Choose configuration data file...'; ru = 'Выберите файл с данными конфигурации...';pl = 'Wybierz plik danych konfiguracji...';es_ES = 'Elegir el archivo de los datos de configuración...';es_CO = 'Elegir el archivo de los datos de configuración...';tr = 'Yapılandırma verileri dosyasını seç ...';it = 'Scegliere il file di configurazione dati...';de = 'Konfigurationsdatendatei wählen...'");
	Dialog.Filter = "Compressed file (*.zip)|*.zip";
	Dialog.Multiselect = False;
	
	NotifyDescription = New NotifyDescription("AfterFileChoise", ThisObject);
	
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure AfterFileChoise(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles <> Undefined Then
		PathToConfigurationPackage = SelectedFiles[0];
		
		Items.GroupPages.CurrentPage = Items.GroupLoadingPage;
		If UpdateConfigurationPackage Then
			AttachIdleHandler("Attachable_FillPredefinedData", 0.2, True);
		Else
			AttachIdleHandler("Attachable_FillCountries", 0.2, True);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

&AtServerNoContext
Function ShowKitProcessingInfobaseUpdate()
	
	If Not AccessRight("Use", Metadata.DataProcessors.KitProcessingInfobaseUpdate) Then
		Return False;
	EndIf;
	
	Result = Not Constants.KitProcessingUpdateWasCompleted.Get();
	
	Return Result;
	
EndFunction

&AtClient
Procedure OpenKitProcessingInfobaseUpdate()
	
	FormParameters = New Structure;
	FormParameters.Insert("FromInfobaseUpdate", True);
	
	OpenForm("DataProcessor.KitProcessingInfobaseUpdate.Form.Form", FormParameters);
	
EndProcedure

&AtServerNoContext
Function ShowMappingGLAccountsToIncomeAndExpenseItems()
	
	If Not AccessRight("Use", Metadata.DataProcessors.MappingGLAccountsToIncomeAndExpenseItems) Then
		Return False;
	EndIf;
	
	Result = Not Constants.EachGLAccountIsMappedToIncomeAndExpenseItem.Get()
		Or Not Constants.EachProfitEstimationGLAccountIsMappedToIncomeAndExpenseItem.Get();
	
	Return Result;
	
EndFunction

&AtClient
Procedure OpenMappingGLAccountsToIncomeAndExpenseItems()
	OpenForm("DataProcessor.MappingGLAccountsToIncomeAndExpenseItems.Form.Form");
EndProcedure

#EndRegion