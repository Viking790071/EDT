
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ValueParameters = Parameters.EquipmentParameters;
	
	Parameters.Property("ID", ID);
	Parameters.Property("HardwareDriver", HardwareDriver);
	
	SuppliedAsDistribution = HardwareDriver.SuppliedAsDistribution;
	DriverVersionInLayout  = HardwareDriver.DriverVersion;
	
	Title = NStr("en = 'Equipment:'; ru = 'Оборудование:';pl = 'Wyposażenie:';es_ES = 'Equipamiento:';es_CO = 'Equipamiento:';tr = 'Ekipman:';it = 'Apparecchiature:';de = 'Ausstattung:'") + Chars.NBSp  + String(ID);

	TextColor = StyleColors.FormTextColor;
	ErrorColor = StyleColors.NegativeTextColor;
	
	CurrentWorksPlace = (SessionParameters.ClientWorkplace = ID.Workplace);
	Items.DeviceTest.Visible         = CurrentWorksPlace;
	Items.SetupDriver.Visible      = CurrentWorksPlace;
	Items.AdditionalActions.Visible = CurrentWorksPlace;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateInformationAboutDriver(True);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Close(GetSettings());    
	
EndProcedure

&AtClient
Procedure DriverSettingEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		GotoURL(DriverImportAddress); 
	EndIf;   
	
EndProcedure

&AtClient
Procedure SetupDriver(Command)
	
	If IntegrationLibrary Then
		Text = NStr("en = 'Driver installation requires connection to the Internet.
		            |Continue?'; 
		            |ru = 'При установке драйвера необходимо подключение к интернету.
		            |Продолжить?';
		            |pl = 'Instalacja sterownika wymaga połączenia z Internetem.
		            |Kontynuować?';
		            |es_ES = 'Instalación del driver requiere la conexión a Internet.
		            |¿Continuar?';
		            |es_CO = 'Instalación del driver requiere la conexión a Internet.
		            |¿Continuar?';
		            |tr = 'Sürücü kurulumu internet bağlantısı gerektiriyor.
		            |Devam etmek istiyor musunuz?';
		            |it = 'L''installazione del Driver richiede la connessione a Internet.
		            |Continuare?';
		            |de = 'Die Treiberinstallation erfordert eine Verbindung mit dem Internet.
		            |Fortsetzen?'");
		Notification = New NotifyDescription("DriverSettingEnd",  ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
	Else
		
		ClearMessages();
		NotificationsDriverFromDistributionOnEnd = New NotifyDescription("SettingDriverFromDistributionOnEnd", ThisObject);
		NotificationsDriverFromArchiveOnEnd = New NotifyDescription("SetDriverFromArchiveOnEnd", ThisObject);
		EquipmentManagerClient.SetupDriver(HardwareDriver, NotificationsDriverFromDistributionOnEnd, NotificationsDriverFromArchiveOnEnd);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDriverFromArchiveOnEnd(Result) Export 
	
	CommonClientServer.MessageToUser(NStr("en = 'Driver is installed.'; ru = 'Установка драйвера завершена.';pl = 'Sterownik jest zainstalowany.';es_ES = 'Driver está instalado.';es_CO = 'Driver está instalado.';tr = 'Sürücü yüklendi.';it = 'Il driver è installato.';de = 'Der Treiber ist installiert.'")); 
	UpdateInformationAboutDriver(True);
	
EndProcedure

&AtClient
Procedure SettingDriverFromDistributionOnEnd(Result, Parameters) Export 
	
	If Result Then
		CommonClientServer.MessageToUser(NStr("en = 'Driver is installed.'; ru = 'Установка драйвера завершена.';pl = 'Sterownik jest zainstalowany.';es_ES = 'Driver está instalado.';es_CO = 'Driver está instalado.';tr = 'Sürücü yüklendi.';it = 'Il driver è installato.';de = 'Der Treiber ist installiert.'")); 
		UpdateInformationAboutDriver(True);
	Else
		CommonClientServer.MessageToUser(NStr("en = 'An error occurred when installing the driver from distribution.'; ru = 'При установке драйвера из дистрибутива произошла ошибка.';pl = 'Wystąpił błąd podczas instalowania sterownika z dystrybucji.';es_ES = 'Ha ocurrido un error al instalar el driver desde la distribución.';es_CO = 'Ha ocurrido un error al instalar el driver desde la distribución.';tr = 'Sürücü dağıtımdan yüklenirken bir hata oluştu.';it = 'Si è verificato un errore durante l''installazione del driver dal distributore.';de = 'Bei der Installation des Treibers aus der Distribution ist ein Fehler aufgetreten.'")); 
	EndIf;

EndProcedure

&AtClient
Procedure DeviceTestEnd(ExecutionResult, Parameters) Export
	
	CommandBar.Enabled = True;
	Items.DriverAndVersion.Enabled = True;
	Items.Pages.Enabled = True;

	AdditionalDetails = "";
	Output_Parameters = ExecutionResult.Output_Parameters;
	
	If TypeOf(Output_Parameters) = Type("Array") Then
		
		If Output_Parameters.Count() >= 2 Then
			AdditionalDetails = Output_Parameters[1];
		EndIf;
		
		If Output_Parameters.Count() >= 3 AND Not IsBlankString(Output_Parameters[2])  Then
			DemoMode = Output_Parameters[2];
			Items.GroupDemoMode.Visible = True;
		EndIf;
		
	EndIf;
		
	MessageText = ?(ExecutionResult.Result,  NStr("en = 'Test succeeded. %AdditionalDetails%'; ru = 'Тест успешно выполнен. %AdditionalDetails%';pl = 'Test przebiegł pomyślnie. %AdditionalDetails%';es_ES = 'Prueba se ha hecho con éxito. %AdditionalDetails%';es_CO = 'Prueba se ha hecho con éxito. %AdditionalDetails%';tr = 'Test başarılı oldu.%AdditionalDetails%';it = 'Test superato. %AdditionalDetails%';de = 'Test erfolgreich %AdditionalDetails%'"),
	                               NStr("en = 'Test failed. %AdditionalDetails%'; ru = 'Тест не пройден. %AdditionalDetails%';pl = 'Nieudany test. %AdditionalDetails%';es_ES = 'Prueba ha fallado. %AdditionalDetails%';es_CO = 'Prueba ha fallado. %AdditionalDetails%';tr = 'Test başarısız. %AdditionalDetails%';it = 'Test fallito. %AdditionalDetails%';de = 'Test fehlgeschlagen. %AdditionalDetails%'"));
	MessageText = StrReplace(MessageText, "%AdditionalDetails%", ?(IsBlankString(AdditionalDetails), "", AdditionalDetails));
	CommonClientServer.MessageToUser(MessageText);
	
EndProcedure

&AtClient
Procedure DeviceTest(Command)
	
	ClearMessages();
	
	TestResult = Undefined;
	DemoMode = "";
	
	Items.GroupDemoMode.Visible = False;
	CommandBar.Enabled = False;
	Items.DriverAndVersion.Enabled = False;
	Items.Pages.Enabled = False;
	
	InputParameters  = Undefined;
	Output_Parameters = Undefined;
	DeviceSettings = GetSettings().EquipmentParameters;
	
	Notification = New NotifyDescription("DeviceTestEnd", ThisObject);
	EquipmentManagerClient.StartExecuteAdditionalCommand(Notification, "CheckHealth", InputParameters, ID, DeviceSettings);
	
EndProcedure

&AtClient
Procedure AdditionalAction(Command)
	
	ClearMessages();
	
	Output_Parameters = Undefined;
	InputParameters  = New Array();
	InputParameters.Add(Mid(Command.Name, 3)); 
	
	Result = EquipmentManagerClient.RunAdditionalCommand("DoAdditionalAction", 
		InputParameters,
		Output_Parameters,
		ID,
		GetSettings());
		
	MessageText = ?(Result,  NStr("en = 'Operation is performed successfully.'; ru = 'Операция выполнена успешно.';pl = 'Operacja została wykonana pomyślnie.';es_ES = 'Operación se ha realizado con éxito.';es_CO = 'Operación se ha realizado con éxito.';tr = 'İşlem başarıyla yapıldı.';it = 'L''operazione è eseguita con successo.';de = 'Die Operation wurde erfolgreich ausgeführt.'"),
		NStr("en = 'Operation execution error.'; ru = 'Ошибка выполнения операции.';pl = 'Błąd podczas wykonania operacji.';es_ES = 'Error de la ejecución de la operación.';es_CO = 'Error de la ejecución de la operación.';tr = 'İşlem yürütme hatası.';it = 'Errore di esecuzione dell''operazione.';de = 'Fehler beim Ausführen der Operation.'") + Chars.NBSp + Output_Parameters[1]);
	CommonClientServer.MessageToUser(MessageText);
	
	ClearCustomInterface();
	
	UpdateInformationAboutDriver(False);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function ClearCustomInterface()
	
	While Items.Pages.ChildItems.Count() > 0 Do
		Items.Delete(Items.Pages.ChildItems.Get(0));
	EndDo;
	
EndFunction

&AtServer
Function GetSettings()
	
	ParametersDriver = GetAttributes();

	ParametersNewValue = New Structure;
	For Each Parameter In ParametersDriver Do
		If Left(Parameter.Name, 2) = "P_" Then
			ParametersNewValue.Insert(Parameter.Name, ThisForm[Parameter.Name]);
		EndIf;
	EndDo;
	
	Result = New Structure;
	Result.Insert("ID", ID);
	Result.Insert("EquipmentParameters", ParametersNewValue);
	Return Result;
	
EndFunction

&AtServer
Procedure RefreshCustomInterface(DetailsInterface, AdditionalActions, FirstLaunch)
	
	BaseGroup = Undefined;
	Item = Undefined;
	GroupIndex = 0;
	PageCount = 0;
	CurrentPage = Items.Add("MainPage", Type("FormGroup"), Items.Pages);
	
	XMLReader = New XMLReader; 
	XMLReader.SetString(DetailsInterface);
	XMLReader.MoveToContent();
	
	If XMLReader.Name = "Settings" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
		While XMLReader.Read() Do  
			
			If XMLReader.Name = "Parameter" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
				
				ParameterEnable = ?(Upper(XMLReader.AttributeValue("ReadOnly")) = "TRUE", True, False) 
										Or ?(Upper(XMLReader.AttributeValue("ReadOnly")) = "TRUE", True, False);
				If ParameterEnable = True Then
					Parameter_Name = "R_" + XMLReader.AttributeValue("Name");
				Else
					Parameter_Name = "P_" + XMLReader.AttributeValue("Name");
				EndIf;
				ParameterTitle   = XMLReader.AttributeValue("Caption");
				ParameterType         = Upper(XMLReader.AttributeValue("TypeValue"));
				ParameterType         = ?(NOT IsBlankString(ParameterType), ParameterType, "STRING");
				ParameterValue    = XMLReader.AttributeValue("DefaultValue");
				ParameterDetails    = XMLReader.AttributeValue("Description");
				
				ParameterExist = False;
				ParametersDriver = GetAttributes();
				For Each ParameterDriver In ParametersDriver Do
					If ParameterDriver.Name = Parameter_Name Then
						ParameterExist = True;
						Break;
					EndIf;
				EndDo;
				
				If Not ParameterExist Then
					
					If ParameterType = "NUMBER" Then 
						Attribute = New FormAttribute(Parameter_Name, New TypeDescription("Number"), , ParameterTitle, True);
					ElsIf ParameterType = "BOOLEAN" Then 
						Attribute = New FormAttribute(Parameter_Name, New TypeDescription("Boolean"), , ParameterTitle, True);
					Else
						Attribute = New FormAttribute(Parameter_Name, New TypeDescription("String"), , ParameterTitle, True);
					EndIf;
				
					// Add new attribute in a form.
					AttributesToAdd = New Array;
					AttributesToAdd.Add(Attribute);
					ChangeAttributes(AttributesToAdd);
				
				EndIf;
				
				If Items.Find(Parameter_Name) = Undefined Then
					// If it wasn't created any group.
					If BaseGroup = Undefined Then
						BaseGroup = Items.Add("BaseGroup" + PageCount, Type("FormGroup"), CurrentPage);
						BaseGroup.Type = FormGroupType.UsualGroup;
						BaseGroup.Representation = Items.DriverAndVersion.Representation;
						BaseGroup.HorizontalStretch = True;
						BaseGroup.Title = NStr("en = 'Parameters'; ru = 'Параметры';pl = 'Parametry';es_ES = 'Parámetros';es_CO = 'Parámetros';tr = 'Parametreler';it = 'Parametri';de = 'Parameter'");
					EndIf;
					// Add new input filed on a form.
					Item = Items.Add(Parameter_Name, Type("FormField"), BaseGroup);
					If ParameterType = "BOOLEAN" Then 
						Item.Type = FormFieldType.CheckBoxField
					Else
						Item.Type = FormFieldType.InputField;
						Item.HorizontalStretch = True;
					EndIf;
					Item.DataPath = Parameter_Name;
					Item.ToolTip = ParameterDetails;
					Item.ReadOnly = ParameterEnable; 
				EndIf;
				
				StoredValue = Undefined;
				If ValueParameters.Property(Parameter_Name, StoredValue) Then
					ParameterValue = StoredValue
				Else
					If Not IsBlankString(ParameterValue) Then
						If ParameterType = "BOOLEAN" Then
							ParameterValue = ?(Upper(ParameterValue) = "TRUE", True, False) Or  ?(Upper(ParameterValue) = "TRUE", True, False);
						ElsIf ParameterType = "STRING" Then
							ParameterValue = String(ParameterValue);
						EndIf;
					EndIf;
				EndIf;
				
				ThisForm[Parameter_Name] = ParameterValue;
				
				MasterParameter         = XMLReader.AttributeValue("MasterParameterName");
				MasterParameterValue = XMLReader.AttributeValue("MasterParameterValue");
				AssistantParameterOperation = XMLReader.AttributeValue("MasterParameterOperation");
				
			EndIf;
			
			If XMLReader.Name = "ChoiceList" AND XMLReader.NodeType = XMLNodeType.StartElement Then 
				
				If Not (Item = Undefined) AND Not (Item.Type = FormFieldType.CheckBoxField) Then   
					Item.ListChoiceMode  = True; 
					Item.TextEdit = False; 
				EndIf;
				
				While XMLReader.Read() AND Not (XMLReader.Name = "ChoiceList") Do   
					
					If XMLReader.Name = "Item" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
						AttributeValue = XMLReader.AttributeValue("Value"); 
						If XMLReader.Read() Then
							AttributePresentation = XMLReader.Value;
						EndIf;
						If IsBlankString(AttributeValue) Then
							AttributeValue = AttributePresentation;
						EndIf;
						
						If ParameterType = "NUMBER" Then 
							Item.ChoiceList.Add(Number(AttributeValue), AttributePresentation)
						Else	
							Item.ChoiceList.Add(AttributeValue, AttributePresentation)
						EndIf;
						
					EndIf;
				EndDo; 
				
			EndIf;
			
			If XMLReader.Name = "Page" AND XMLReader.NodeType = XMLNodeType.StartElement Then
				
				PageTitle = XMLReader.AttributeValue("Caption");
				PageTitle = ?(IsBlankString(PageTitle), NStr("en = 'Parameters'; ru = 'Параметры';pl = 'Parametry';es_ES = 'Parámetros';es_CO = 'Parámetros';tr = 'Parametreler';it = 'Parametri';de = 'Parameter'"), PageTitle);
				
				PageCount = PageCount + 1;
				If PageCount > 1 Then
					Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
					CurrentPage = Items.Add("Page" + PageCount, Type("FormGroup"), Items.Pages);
					BaseGroup = Undefined;
				EndIf;
				CurrentPage.Title = PageTitle;
				
			EndIf;
				
			If XMLReader.Name = "Group" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
				
				TitleGroups = XMLReader.AttributeValue("Caption");
				TitleGroups = ?(IsBlankString(TitleGroups), NStr("en = 'Parameters'; ru = 'Параметры';pl = 'Parametry';es_ES = 'Parámetros';es_CO = 'Parámetros';tr = 'Parametreler';it = 'Parametri';de = 'Parameter'"), TitleGroups);
				
				BaseGroup = Items.Add("Group" + GroupIndex, Type("FormGroup"), CurrentPage);
				BaseGroup.Type = FormGroupType.UsualGroup;
				BaseGroup.Representation = Items.DriverAndVersion.Representation;
				BaseGroup.HorizontalStretch = True;
				BaseGroup.Title = TitleGroups;
				BaseGroup.Group = ChildFormItemsGroup.Vertical;
				GroupIndex = GroupIndex + 1;
				
			EndIf;
			
		EndDo;  
		
	EndIf;
	
	XMLReader.Close(); 
	
	If FirstLaunch AND Not IsBlankString(AdditionalActions) Then
		
		XMLReader = New XMLReader; 
		XMLReader.SetString(AdditionalActions);
		XMLReader.MoveToContent();
		
		If XMLReader.Name = "Actions" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
			
			While XMLReader.Read() Do  
				If XMLReader.Name = "Action" AND XMLReader.NodeType = XMLNodeType.StartElement Then  
					
					ActionName       = "M_"  + XMLReader.AttributeValue("Name");
					ActionTitle = XMLReader.AttributeValue("Caption");
					
					Command = Commands.Add("A_" + XMLReader.AttributeValue("Name"));
					Command.Title = ActionTitle;
					Command.Action = "AdditionalAction";
					
					PointMenu = Items.Add(ActionName, Type("FormButton"), Items.AdditionalActions);
					PointMenu.Type = FormButtonType.CommandBarButton;
					PointMenu.Title = ActionTitle;
					PointMenu.CommandName = "A_" + XMLReader.AttributeValue("Name");
					 
				EndIf;
			EndDo;  
			
		EndIf;
		
		XMLReader.Close(); 
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StartAdditionalCommandExecutionEnd(ExecutionResult, Parameters) Export
	
	If Not TypeOf(ExecutionResult) = Type("Structure") Then
		Return;
	EndIf;
	
	FirstLaunch = ?(Parameters.Property("FirstLaunch"), Parameters.FirstLaunch, True);
	Output_Parameters = ExecutionResult.Output_Parameters;
		
	If ExecutionResult.Result Then
		DriverIsSet         = Output_Parameters[0];
		DriverVersion            = Output_Parameters[1];
		DriverDescription      = Output_Parameters[2];
		DetailsDriver          = Output_Parameters[3];
		EquipmentType           = Output_Parameters[4];
		AuditInterface         = Output_Parameters[5];
		IntegrationLibrary  = Output_Parameters[6];
		MainDriverIsSet = Output_Parameters[7];
		DriverImportAddress     = Output_Parameters[8];
		ParametersDriver         = Output_Parameters[9];
		AdditionalActions    = Output_Parameters[10];
		
		If (IntegrationLibrary AND MainDriverIsSet) Or (NOT IntegrationLibrary) Then
			If Not IsBlankString(ParametersDriver) Then
				RefreshCustomInterface(ParametersDriver, AdditionalActions, FirstLaunch);
			EndIf;
		EndIf;
		
		If IntegrationLibrary AND Not MainDriverIsSet Then
			DriverIsSet = NStr("en = 'Integration library is installed'; ru = 'Установлена интеграционная библиотека';pl = 'Zainstalowano bibliotekę integracji';es_ES = 'Biblioteca de integración está instalada';es_CO = 'Biblioteca de integración está instalada';tr = 'Entegrasyon kütüphanesi kuruldu';it = 'La libreria di integrazione è installata';de = 'Integrationsbibliothek ist installiert'");
			DriverVersion = NStr("en = 'Not defined'; ru = 'Не определена';pl = 'Nieokreślona';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non definito';de = 'Nicht definiert'");
			Items.SetupDriver.Title = NStr("en = 'Install the main driver supply'; ru = 'Установить основную поставку драйвера';pl = 'Zainstaluj główny sterownik';es_ES = 'Instalar el suministro del driver principal';es_CO = 'Instalar el suministro del driver principal';tr = 'Ana sürücü teslimatını kurun';it = 'Installare l''alimentazione principale del driver';de = 'Installieren Sie die Haupttreiberversorgung'");
		EndIf;
		Items.DriverAndVersion.Enabled = True;
	Else
		DriverMessage  = Output_Parameters[1];
		DriverIsSet = Output_Parameters[2];
		DriverVersion  = NStr("en = 'Not defined'; ru = 'Не определена';pl = 'Nieokreślona';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non definito';de = 'Nicht definiert'");
		If Not IsBlankString(DriverMessage) AND DriverIsSet = NStr("en = 'Set'; ru = 'установки';pl = 'Ustaw';es_ES = 'Establecer';es_CO = 'Establecer';tr = 'Ayarla';it = 'Imposta';de = 'Einstellen'") Then
			Items.DevicePlugged.Visible = True;
			Items.DevicePlugged.Title = DriverMessage;
			Items.WriteAndClose.Visible = False;
			Items.DriverAndVersion.Visible   = False;
			Items.Functions.Visible = False;
			Items.Close.Visible = True;
		EndIf
	EndIf;
	
	Items.Driver.TextColor = ?(DriverVersion = NStr("en = 'Not defined'; ru = 'Не определена';pl = 'Nieokreślona';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non definito';de = 'Nicht definiert'"), ErrorColor, TextColor);
	Items.Version.TextColor  = Items.Driver.TextColor ;
	Items.DriverDescription.TextColor = ?(DriverDescription = NStr("en = 'Undefined'; ru = 'Неопределено';pl = 'Nieokreślone';es_ES = 'No definido';es_CO = 'No definido';tr = 'Tanımlanmamış';it = 'Non definito';de = 'Nicht definiert'"), ErrorColor, TextColor);
	Items.DetailsDriver.TextColor     = ?(DetailsDriver     = NStr("en = 'Undefined'; ru = 'Неопределено';pl = 'Nieokreślone';es_ES = 'No definido';es_CO = 'No definido';tr = 'Tanımlanmamış';it = 'Non definito';de = 'Nicht definiert'"), ErrorColor, TextColor);
	Items.DetailsDriver.Visible = Not IsBlankString(DetailsDriver);
	
	Items.SetupDriver.Enabled = Not (DriverIsSet = NStr("en = 'Set'; ru = 'установки';pl = 'Ustaw';es_ES = 'Establecer';es_CO = 'Establecer';tr = 'Ayarla';it = 'Imposta';de = 'Einstellen'"));
	Items.DeviceTest.Enabled = (NOT DriverIsSet = NStr("en = 'Not set'; ru = 'Не установлен';pl = 'Nieustawiony';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non impostato';de = 'Nicht eingestellt'")) 
	                                      AND (NOT IntegrationLibrary Or (IntegrationLibrary AND MainDriverIsSet));
	
EndProcedure

&AtClient
Procedure UpdateInformationAboutDriver(FirstLaunch)

	InputParameters  = Undefined;
	DeviceSettings = Undefined;
	CommandParameters = New Structure("FirstLaunch", FirstLaunch);
	Notification = New NotifyDescription("StartAdditionalCommandExecutionEnd", ThisObject, CommandParameters);
	EquipmentManagerClient.StartExecuteAdditionalCommand(Notification, "GetDriverDescription", InputParameters, ID, DeviceSettings);
	  
EndProcedure

#EndRegion