
#Region ProceduresAndFunctionsEnableDisableEquipmentSynchronously

// Connects available peripherals from a list of available peripherals
//
Function ConnectEquipmentByType(ClientID, EETypes, ErrorDescription = "") Export
	
	StructureSWTypes = New Structure();
	If TypeOf(EETypes) = Type("Array") Then
		For Each EEType In EETypes Do
			StructureSWTypes.Insert(EEType);
		EndDo;
	Else
		StructureSWTypes.Insert(EETypes);
	EndIf;
	
	Return ConnectEquipment(ClientID, StructureSWTypes, , ErrorDescription);
	 
EndFunction

// Enables device single copy defined by identifier.
//
Function ConnectEquipmentByID(ClientID, DeviceIdentifier, ErrorDescription = "") Export
	
	Return ConnectEquipment(ClientID, , DeviceIdentifier, ErrorDescription);
	
EndFunction

// Function enables devices by the equipment type.
// Returns the result of function execution.
Function ConnectEquipment(ClientID, EETypes = Undefined,
							   DeviceIdentifier = Undefined, ErrorDescription = "") Export
	   
	FinalResult = True;
	Result         = True;
	
	DriverObject    = Undefined;
	ErrorDescription    = "";
	DeviceErrorDescription = "";

	Result = RefreshClientWorkplace();
	If Not Result Then
		ErrorDescription = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
		Return False;
	EndIf;
	
	EquipmentList = EquipmentManagerClientReUse.GetEquipmentList(EETypes, DeviceIdentifier);
	
	If EquipmentList.Count() > 0 Then
		For Each Device In EquipmentList Do
			
			// Check if the device is enabled earlier.
			ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, Device.Ref);
			
			If ConnectedDevice = Undefined Then // If device is not enabled earlier.
				DriverObject = GetDriverObject(Device);
				If DriverObject = Undefined Then
					// Error message prompting that the driver can not be imported.
					ErrorDescription = ErrorDescription + ?(IsBlankString(ErrorDescription), "", Chars.LF)
								   + NStr("en = '%Description%: Cannot export the peripheral driver.
								          |Check if the driver is correctly installed and registered in the system.'; 
								          |ru = '%Description%: Не удалось загрузить драйвер устройства.
								          |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
								          |pl = '%Description%: Nie można wyeksportować sterownika urządzenia peryferyjnego.
								          |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
								          |es_ES = '%Description%: No se puede exportar el driver de periféricos.
								          |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
								          |es_CO = '%Description%: No se puede exportar el driver de periféricos.
								          |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
								          |tr = '%Description%: Çevre birimi sürücüsü dışa aktarılamıyor.
								          |Sürücünün sistemde doğru şekilde kurulduğundan ve kayıtlı olduğundan emin olun.';
								          |it = '%Description%: Non è possibile esportare il driver della periferica.
								          |Controllare se il driver è installato correttamente e registrato nel sistema.';
								          |de = '%Description%: Der Peripherietreiber kann nicht exportiert werden.
								          |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
					ErrorDescription = StrReplace(ErrorDescription, "%Description%", Device.Description);
					FinalResult = False;
					Continue;
				EndIf;
				
				ANewConnection = New Structure();
				ANewConnection.Insert("Clients"               , New Array());
				ANewConnection.Clients.Add(ClientID);
				ANewConnection.Insert("Ref"                 , Device.Ref);
				ANewConnection.Insert("DeviceIdentifier", Device.DeviceIdentifier);
				ANewConnection.Insert("DriverHandler"     , Device.DriverHandler);
				ANewConnection.Insert("Description"           , Device.Description);
				ANewConnection.Insert("EquipmentType"        , Device.EquipmentType);
				ANewConnection.Insert("HardwareDriver"    , Device.HardwareDriver);
				ANewConnection.Insert("AsConfigurationPart"   , Device.AsConfigurationPart);
				ANewConnection.Insert("ObjectID"   , Device.ObjectID);
				ANewConnection.Insert("DriverTemplateName"      , Device.DriverTemplateName);
				ANewConnection.Insert("DriverFileName"       , Device.DriverFileName);
				ANewConnection.Insert("Workplace"           , Device.Workplace);
				ANewConnection.Insert("ComputerName"          , Device.ComputerName);
				ANewConnection.Insert("Parameters"              , Device.Parameters);
				ANewConnection.Insert("CountOfConnected" , 1);
				ANewConnection.Insert("ConnectionParameters"   , New Structure());
				ANewConnection.ConnectionParameters.Insert("EquipmentType", Device.EquipmentTypeName);
				
				Output_Parameters = Undefined;
				
				DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ANewConnection.DriverHandler, Not ANewConnection.AsConfigurationPart);
				If DriverHandler = Undefined Then
					// Error message prompting that the driver can not be imported.
					ErrorDescription = ErrorDescription +  NStr("en = 'Cannot connect the driver handler.'; ru = 'Не удалось подключить обработчик драйвера.';pl = 'Nie można podłączyć sterownika obsługi.';es_ES = 'No se puede conectar el manipulador del driver.';es_CO = 'No se puede conectar el manipulador del driver.';tr = 'Sürücü işleyicisi bağlanılamıyor.';it = 'Non è possibile collegarsi al gestore del driver.';de = 'Der Treiber-Handler kann nicht verbunden werden.'");
					FinalResult = False;
					Continue;
				Else
					// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
					If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
						DriverHandler = PeripheralsUniversalDriverClient;
					EndIf;
					
					Result = DriverHandler.ConnectDevice(
						DriverObject,
						ANewConnection.Parameters,
						ANewConnection.ConnectionParameters,
						Output_Parameters);
				EndIf;
				
				If Result Then
					If Output_Parameters.Count() >= 2 Then
						ANewConnection.Insert("EventSource", Output_Parameters[0]);
						ANewConnection.Insert("NamesEvents",    Output_Parameters[1]);
					Else
						ANewConnection.Insert("EventSource", "");
						ANewConnection.Insert("NamesEvents",    Undefined);
					EndIf;
					glPeripherals.PeripheralsConnectingParameters.Add(ANewConnection);
				Else
					// Inform user that a peripheral failed to be connected.
					ErrorDescription = ErrorDescription + ?(IsBlankString(ErrorDescription), "", Chars.LF)
								   + NStr("en = 'Cannot connect the ""%Description%"" device: %ErrorDescription% (%ErrorCode%)'; ru = 'Не удалось подключить устройство ""%Description%"": %ErrorDescription% (%ErrorCode%)';pl = 'Nie można podłączyć urządzenia ""%Description%"" urządzenie: %ErrorDescription% (%ErrorCode%)';es_ES = 'No se puede conectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';es_CO = 'No se puede conectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';tr = '""%Description%"" cihazına bağlanılamıyor:%ErrorDescription% (%ErrorCode%)';it = 'Non è possibile collegare il dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';de = 'Das ""%Description%""-Gerät kann nicht angeschlossen werden: %ErrorDescription% (%ErrorCode%)'");
					ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , Device.Description);
					ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
					ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Output_Parameters[0]);
				EndIf;
			Else // Device was enabled earlier.
				// Increase quantity of this connection users.
				ConnectedDevice.Clients.Add(ClientID);
				ConnectedDevice.CountOfConnected = ConnectedDevice.CountOfConnected + 1;
			EndIf;
			
			FinalResult = FinalResult AND Result;
		EndDo;
	ElsIf DeviceIdentifier <> Undefined Then
		ErrorDescription = NStr("en = 'The selected peripheral can not be used for connection.
		                        |Specify other device.'; 
		                        |ru = 'Выбранное устройство не может использоваться для подключения.
		                        |Укажите другое устройство.';
		                        |pl = 'Wybrane urządzenie nie może być używane do podłączenia.
		                        |Określ inne urządzenie.';
		                        |es_ES = 'El periférico seleccionado no puede utilizarse para conectar.
		                        |Especificar otro dispositivo.';
		                        |es_CO = 'El periférico seleccionado no puede utilizarse para conectar.
		                        |Especificar otro dispositivo.';
		                        |tr = 'Seçilen çevre birimi bağlantı için kullanılamaz. 
		                        |Diğer cihazı belirtin.';
		                        |it = 'Il dispositivo selezionato non può essere utilizzato per la connessione.
		                        |Si prega di inserire un dispositivo diverso.';
		                        |de = 'Das ausgewählte Peripheriegerät kann nicht für die Verbindung verwendet werden.
		                        |Andere Geräte angeben'");
		FinalResult = False;
	EndIf;

	Return FinalResult;

EndFunction

// Search by identifier of the previously connected peripheral.
//
Function GetConnectedDevice(ConnectionsList, ID) Export
	
	ConnectedDevice = Undefined;
	
	For Each Connection In ConnectionsList Do
		If Connection.Ref = ID Then
			ConnectedDevice = Connection;
			Break;
		EndIf;
	EndDo;
	
	Return ConnectedDevice;
	
EndFunction

// Disables devices by the equipment type.
//
Function DisableEquipmentByType(ClientID, EETypes, ErrorDescription = "") Export

	Return DisableEquipment(ClientID, EETypes, ,ErrorDescription);

EndFunction

// Disables device defined by identifier.
//
Function DisableEquipmentById(ClientID, DeviceIdentifier, ErrorDescription = "") Export

	Return DisableEquipment(ClientID, , DeviceIdentifier, ErrorDescription);

EndFunction

// Forcefully disables all peripherals
// regardless of refs to connection quantity.
Function DisableAllEquipment(ErrorDescription = "") Export
	
	FinalResult = True;
	Result         = True;
	
	For Each ConnectedDevice In glPeripherals.PeripheralsConnectingParameters Do
		
		DriverObject = GetDriverObject(ConnectedDevice);
		If DriverObject = Undefined Then
			// Error message prompting that the driver can not be imported.
			ErrorDescription = NStr("en = '""%Description%"": Cannot export the peripheral driver.
			                        |Check if the driver is correctly installed and registered in the system.'; 
			                        |ru = '%Description%: Не удалось загрузить драйвер устройства.
			                        |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
			                        |pl = '""%Description%"": Nie można wyeksportować sterownika urządzenia peryferyjnego.
			                        |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
			                        |es_ES = '""%Description%"": No se puede exportar el driver de periféricos.
			                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                        |es_CO = '""%Description%"": No se puede exportar el driver de periféricos.
			                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                        |tr = '""%Description%"": Çevre birimi sürücüsü dışa aktarılamıyor.
			                        |Sürücünün sistemde doğru şekilde kurulduğundan ve kayıtlı olduğundan emin olun.';
			                        |it = '%Description%: Non è possibile esportare il driver della periferica.
			                        |Controllare se il driver è installato correttamente e registrato nel sistema.';
			                        |de = '""%Description%"": Der Peripherietreiber kann nicht exportiert werden.
			                        |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
			FinalResult = False;
			Continue;
		EndIf;
		
		Output_Parameters = Undefined;
		
		DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ConnectedDevice.DriverHandler, Not ConnectedDevice.AsConfigurationPart);
		
		// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
		If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
			DriverHandler = PeripheralsUniversalDriverClient;
		EndIf;
	
		Result = DriverHandler.DisableDevice(
				DriverObject,
				ConnectedDevice.Parameters,
				ConnectedDevice.ConnectionParameters,
				Output_Parameters);
				
		If Not Result Then
			ErrorDescription = NStr("en = 'An error occurred when disconnecting the ""%Description%"" device: %ErrorDescription% (%ErrorCode%)'; ru = 'При отключении устройства ""%Description%"" произошла ошибка: %ErrorDescription% (%ErrorCode%)';pl = 'Wystąpił błąd podczas odłączania ""%Description%"" urządzenia: %ErrorDescription% (%ErrorCode%)';es_ES = 'Ha ocurrido un error al desconectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';es_CO = 'Ha ocurrido un error al desconectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';tr = '""%Description%"" cihazının bağlantısı kesilirken hata oluştu: %ErrorDescription% (%ErrorCode%)';it = 'Si è verificato un errore durante la disconnessione del ""%Description%"" device: %ErrorDescription% (%ErrorCode%)';de = 'Beim Trennen der ""%Description%"" Vorrichtung ist ein Fehler aufgetreten: %ErrorDescription%(%ErrorCode%)'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%", Output_Parameters[0]);
		Else
			ConnectedDevice.CountOfConnected = 0;
		EndIf;
		FinalResult = FinalResult AND Result;
	EndDo;
	
	glPeripherals.PeripheralsConnectingParameters.Clear();
	
	Return FinalResult;
	
EndFunction

// Function enables devices by the equipment type.
// 
Function DisableEquipment(ClientID, EETypes = Undefined, DeviceIdentifier = Undefined, ErrorDescription = "")
	
	FinalResult = True;
	Result         = True;
	
	OutputErrorDescription = "";
	
	If glPeripherals.PeripheralsConnectingParameters <> Undefined Then
		CountDevices = glPeripherals.PeripheralsConnectingParameters.Count();
		For IndexOf = 1 To CountDevices Do
			
			ConnectedDevice = glPeripherals.PeripheralsConnectingParameters[CountDevices - IndexOf];
			TypeNameOfSoftware = EquipmentManagerClientReUse.GetEquipmentTypeName(ConnectedDevice.EquipmentType);
			ClientConnection = ConnectedDevice.Clients.Find(ClientID);
			If ClientConnection <> Undefined  AND (EETypes = Undefined Or EETypes.Find(TypeNameOfSoftware) <> Undefined)
			   AND (DeviceIdentifier = Undefined  Or ConnectedDevice.Ref = DeviceIdentifier)Then
				 
				 If ConnectedDevice.CountOfConnected = 1 Then
					 
					DriverObject = GetDriverObject(ConnectedDevice);
					If DriverObject = Undefined Then
						// Error message prompting that the driver can not be imported.
						ErrorDescription = NStr("en = '""%Description%"": Cannot export the peripheral driver.
						                        |Check if the driver is correctly installed and registered in the system.'; 
						                        |ru = '%Description%: Не удалось загрузить драйвер устройства.
						                        |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
						                        |pl = '""%Description%"": Nie można wyeksportować sterownika urządzenia peryferyjnego.
						                        |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
						                        |es_ES = '""%Description%"": No se puede exportar el driver de periféricos.
						                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
						                        |es_CO = '""%Description%"": No se puede exportar el driver de periféricos.
						                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
						                        |tr = '""%Description%"": Çevre birimi sürücüsü dışa aktarılamıyor.
						                        |Sürücünün sistemde doğru şekilde kurulduğundan ve kayıtlı olduğundan emin olun.';
						                        |it = '%Description%: Non è possibile esportare il driver della periferica.
						                        |Controllare se il driver è installato correttamente e registrato nel sistema.';
						                        |de = '""%Description%"": Der Peripherietreiber kann nicht exportiert werden.
						                        |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
						ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
						FinalResult = False;
						Continue;
					EndIf;
					
					Output_Parameters = Undefined;
					
					DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ConnectedDevice.DriverHandler, Not ConnectedDevice.AsConfigurationPart);
					
					// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
					If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
						DriverHandler = PeripheralsUniversalDriverClient;
					EndIf;
					
					Result = DriverHandler.DisableDevice(
							DriverObject,
							ConnectedDevice.Parameters,
							ConnectedDevice.ConnectionParameters,
							Output_Parameters);
							
					If Not Result Then
						ErrorDescription = ErrorDescription + ?(IsBlankString(ErrorDescription), "", Chars.LF)
									   + NStr("en = 'An error occurred when disconnecting the ""%Description%"" device: %ErrorDescription% (%ErrorCode%)'; ru = 'При отключении устройства ""%Description%"" произошла ошибка: %ErrorDescription% (%ErrorCode%)';pl = 'Wystąpił błąd podczas odłączania ""%Description%"" urządzenia: %ErrorDescription% (%ErrorCode%)';es_ES = 'Ha ocurrido un error al desconectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';es_CO = 'Ha ocurrido un error al desconectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';tr = '""%Description%"" cihazının bağlantısı kesilirken hata oluştu: %ErrorDescription% (%ErrorCode%)';it = 'Si è verificato un errore durante la disconnessione del ""%Description%"" device: %ErrorDescription% (%ErrorCode%)';de = 'Beim Trennen der ""%Description%"" Vorrichtung ist ein Fehler aufgetreten: %ErrorDescription%(%ErrorCode%)'");
						ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
						ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
						ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%", Output_Parameters[0]);
					Else
						ConnectedDevice.CountOfConnected = 0;
					EndIf;
					
					ArrayLineNumber = glPeripherals.PeripheralsConnectingParameters.Find(ConnectedDevice);
					If ArrayLineNumber <> Undefined Then
						glPeripherals.PeripheralsConnectingParameters.Delete(ArrayLineNumber);
					EndIf;
				Else
					ConnectedDevice.CountOfConnected = ConnectedDevice.CountOfConnected - 1;
					ConnectedDevice.Clients.Delete(ClientConnection);
				EndIf;
			EndIf;
			
			FinalResult = FinalResult AND Result;
		EndDo;
	EndIf;
	
	Return FinalResult;
	
EndFunction

#EndRegion   

#Region ProceduresAndFunctionsEquipmentConnectionAsynchronously

// Connects available peripherals from a list of available peripherals
//
Procedure StartEnableEquipmentByType(AlertOnConnect, ClientID, EETypes) Export
	
	StructureSWTypes = New Structure();
	If TypeOf(EETypes) = Type("Array") Then
		For Each EEType In EETypes Do
			StructureSWTypes.Insert(EEType);
		EndDo;
	Else
		StructureSWTypes.Insert(EETypes);
	EndIf;
	
	StartConnectPeripheral(AlertOnConnect, ClientID, StructureSWTypes);
	 
EndProcedure

// Start enabling device single copy defined by identifier.
//
Procedure StartEquipmentEnablingByIdidentifier(AlertOnConnect, ClientID, DeviceIdentifier) Export
	
	StartConnectPeripheral(AlertOnConnect, ClientID, , DeviceIdentifier);
	
EndProcedure

Procedure StartEnableEquipmentEnd(ExecutionResult, Parameters) Export
	
	If ExecutionResult.Result Then
		If ExecutionResult.Output_Parameters.Count() >= 2 Then
			Parameters.ANewConnection.Insert("EventSource", Parameters.Output_Parameters[0]);
			Parameters.ANewConnection.Insert("NamesEvents",    Parameters.Output_Parameters[1]);
		Else
			Parameters.ANewConnection.Insert("EventSource", "");
			Parameters.ANewConnection.Insert("NamesEvents",    Undefined);
		EndIf;
		glPeripherals.PeripheralsConnectingParameters.Add(Parameters.ANewConnection);
		If Parameters.AlertOnConnect <> Undefined Then
			ErrorDescription = NStr("en = 'No errors.'; ru = 'Ошибок нет.';pl = 'Bez błędów.';es_ES = 'No hay errores.';es_CO = 'No hay errores.';tr = 'Hata yok.';it = 'Nessun errore.';de = 'Keine fehler.'");
			ExecutionResult = New Structure("Result, ErrorDetails", True, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnConnect, ExecutionResult);
		EndIf;
	Else
		// Inform user that a peripheral failed to be connected.
		If Parameters.AlertOnConnect <> Undefined Then
			ErrorDescription = NStr("en = 'Cannot connect the ""%Description%"" device: %ErrorDescription% (%ErrorCode%)'; ru = 'Не удалось подключить устройство ""%Description%"": %ErrorDescription% (%ErrorCode%)';pl = 'Nie można podłączyć urządzenia ""%Description%"" urządzenie: %ErrorDescription% (%ErrorCode%)';es_ES = 'No se puede conectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';es_CO = 'No se puede conectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';tr = '""%Description%"" cihazına bağlanılamıyor:%ErrorDescription% (%ErrorCode%)';it = 'Non è possibile collegare il dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';de = 'Das ""%Description%""-Gerät kann nicht angeschlossen werden: %ErrorDescription% (%ErrorCode%)'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , Parameters.ANewConnection.Description);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Parameters.Output_Parameters[1]);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Parameters.Output_Parameters[0]);
			ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnConnect, ExecutionResult);
		EndIf;
	EndIf;
	
EndProcedure

Procedure StartEnablingDeviceGettingDriverObjectEnd(DriverObject, Parameters) Export
	
	If DriverObject = Undefined Then
		
		If Parameters.AlertOnConnect <> Undefined Then
			// Error message prompting that the driver can not be imported.
			ErrorDescription = NStr("en = '%Description%: Cannot export the peripheral driver.
			                        |Check if the driver is correctly installed and registered in the system.'; 
			                        |ru = '%Description%: Не удалось загрузить драйвер устройства.
			                        |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
			                        |pl = '%Description%: Nie można wyeksportować sterownika urządzenia peryferyjnego.
			                        |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
			                        |es_ES = '%Description%: No se puede exportar el driver de periféricos.
			                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                        |es_CO = '%Description%: No se puede exportar el driver de periféricos.
			                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                        |tr = '%Description%: Çevre birimi sürücüsü dışa aktarılamıyor.
			                        |Sürücünün sistemde doğru şekilde kurulduğundan ve kayıtlı olduğundan emin olun.';
			                        |it = '%Description%: Non è possibile esportare il driver della periferica.
			                        |Controllare se il driver è installato correttamente e registrato nel sistema.';
			                        |de = '%Description%: Der Peripherietreiber kann nicht exportiert werden.
			                        |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", Parameters.ANewConnection.Description);
			ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnConnect, ExecutionResult);
		EndIf;
		
	Else
		Notification = New NotifyDescription("StartEnableEquipmentEnd", ThisObject, Parameters);
		Parameters.DriverHandler.StartEnableDevice(Notification, DriverObject, 
			 Parameters.ANewConnection.Parameters,  Parameters.ANewConnection.ConnectionParameters, Parameters);
	EndIf;
	
EndProcedure

// Start connecting a peripheral.
// 
Procedure StartConnectPeripheral(AlertOnConnect, ClientID, EETypes = Undefined, DeviceIdentifier = Undefined) Export
	   
	DriverObject = Undefined;
	
	Result = RefreshClientWorkplace();
	If Not Result Then
		If AlertOnConnect <> Undefined Then
			ErrorDescription = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
			ExecutionResult = New Structure("Result, ErrorDetails", Result, ErrorDescription);
			ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
		EndIf;
	EndIf;
	
	EquipmentList = EquipmentManagerClientReUse.GetEquipmentList(EETypes, DeviceIdentifier);
	
	If EquipmentList.Count() > 0 Then
		For Each Device In EquipmentList Do
			
			// Check if the device is enabled earlier.
			ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, Device.Ref);
			
			If ConnectedDevice = Undefined Then // If device is not enabled earlier.
				
				DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(Device.DriverHandler, Not Device.AsConfigurationPart);
				
				ANewConnection = New Structure();
				ANewConnection.Insert("Clients"               , New Array());
				ANewConnection.Clients.Add(ClientID);
				ANewConnection.Insert("Ref"                 , Device.Ref);
				ANewConnection.Insert("DeviceIdentifier", Device.DeviceIdentifier);
				ANewConnection.Insert("DriverHandler"     , Device.DriverHandler);
				ANewConnection.Insert("Description"           , Device.Description);
				ANewConnection.Insert("EquipmentType"        , Device.EquipmentType);
				ANewConnection.Insert("HardwareDriver"    , Device.HardwareDriver);
				ANewConnection.Insert("AsConfigurationPart"   , Device.AsConfigurationPart);
				ANewConnection.Insert("ObjectID"   , Device.ObjectID);
				ANewConnection.Insert("DriverTemplateName"      , Device.DriverTemplateName);
				ANewConnection.Insert("DriverFileName"       , Device.DriverFileName);
				ANewConnection.Insert("Workplace"           , Device.Workplace);
				ANewConnection.Insert("ComputerName"          , Device.ComputerName);
				ANewConnection.Insert("Parameters"              , Device.Parameters);
				ANewConnection.Insert("CountOfConnected" , 1);
				ANewConnection.Insert("ConnectionParameters"   , New Structure());
				ANewConnection.ConnectionParameters.Insert("EquipmentType", Device.EquipmentTypeName);
				
				If DriverHandler = Undefined Then
					// Report an error: can not connect the handler.
					If AlertOnConnect <> Undefined Then
						ErrorDescription = NStr("en = 'Cannot connect the driver handler.'; ru = 'Не удалось подключить обработчик драйвера.';pl = 'Nie można podłączyć sterownika obsługi.';es_ES = 'No se puede conectar el manipulador del driver.';es_CO = 'No se puede conectar el manipulador del driver.';tr = 'Sürücü işleyicisi bağlanılamıyor.';it = 'Non è possibile collegarsi al gestore del driver.';de = 'Der Treiber-Handler kann nicht verbunden werden.'");
						ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
						ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
					EndIf;
					Continue;
				Else
					
					// Split on asynchronous and synchronous calls.
					If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
						// Asynchronous calls
						CommandParameters = New Structure("NewConnection, AlertOnEnabling, DriverHandler", ANewConnection, AlertOnConnect, DriverHandler);
						Notification = New NotifyDescription("StartEnablingDeviceGettingDriverObjectEnd", ThisObject, CommandParameters);
						StartReceivingDriverObject(Notification, Device);
					Else
						// Simultaneous
						DriverObject = GetDriverObject(Device);
						If DriverObject = Undefined Then
							If AlertOnConnect <> Undefined Then
								// Error message prompting that the driver can not be imported.
								ErrorDescription = NStr("en = '%Description%: Cannot export the peripheral driver.
								                        |Check if the driver is correctly installed and registered in the system.'; 
								                        |ru = '%Description%: Не удалось загрузить драйвер устройства.
								                        |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
								                        |pl = '%Description%: Nie można wyeksportować sterownika urządzenia peryferyjnego.
								                        |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
								                        |es_ES = '%Description%: No se puede exportar el driver de periféricos.
								                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
								                        |es_CO = '%Description%: No se puede exportar el driver de periféricos.
								                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
								                        |tr = '%Description%: Çevre birimi sürücüsü dışa aktarılamıyor.
								                        |Sürücünün sistemde doğru şekilde kurulduğundan ve kayıtlı olduğundan emin olun.';
								                        |it = '%Description%: Non è possibile esportare il driver della periferica.
								                        |Controllare se il driver è installato correttamente e registrato nel sistema.';
								                        |de = '%Description%: Der Peripherietreiber kann nicht exportiert werden.
								                        |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
								ErrorDescription = StrReplace(ErrorDescription, "%Description%",ANewConnection.Description);
								ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
								ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
							EndIf;
							Continue;
						Else
							Output_Parameters = Undefined;
							Result = DriverHandler.ConnectDevice(DriverObject, ANewConnection.Parameters, ANewConnection.ConnectionParameters, Output_Parameters);
							
							If Result Then
								
								If Output_Parameters.Count() >= 2 Then
									ANewConnection.Insert("EventSource", Output_Parameters[0]);
									ANewConnection.Insert("NamesEvents",    Output_Parameters[1]);
								Else
									ANewConnection.Insert("EventSource", "");
									ANewConnection.Insert("NamesEvents",    Undefined);
								EndIf;
								glPeripherals.PeripheralsConnectingParameters.Add(ANewConnection);
								
								If AlertOnConnect <> Undefined Then
									ErrorDescription = NStr("en = 'No errors.'; ru = 'Ошибок нет.';pl = 'Bez błędów.';es_ES = 'No hay errores.';es_CO = 'No hay errores.';tr = 'Hata yok.';it = 'Nessun errore.';de = 'Keine fehler.'");
									ExecutionResult = New Structure("Result, ErrorDetails", True, ErrorDescription);
									ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
								EndIf;
								
							Else
								// Inform user that a peripheral failed to be connected.
								If AlertOnConnect <> Undefined Then
									ErrorDescription = NStr("en = 'Cannot connect the ""%Description%"" device: %ErrorDescription% (%ErrorCode%)'; ru = 'Не удалось подключить устройство ""%Description%"": %ErrorDescription% (%ErrorCode%)';pl = 'Nie można podłączyć urządzenia ""%Description%"" urządzenie: %ErrorDescription% (%ErrorCode%)';es_ES = 'No se puede conectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';es_CO = 'No se puede conectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';tr = '""%Description%"" cihazına bağlanılamıyor:%ErrorDescription% (%ErrorCode%)';it = 'Non è possibile collegare il dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';de = 'Das ""%Description%""-Gerät kann nicht angeschlossen werden: %ErrorDescription% (%ErrorCode%)'");
									ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , ANewConnection.Description);
									ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
									ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Output_Parameters[0]);
									ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
									ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
								EndIf;
							EndIf;
						EndIf;
						
					EndIf;
					
				EndIf;
			
			Else // Device was enabled earlier.
				// Increase quantity of this connection users.
				ConnectedDevice.Clients.Add(ClientID);
				ConnectedDevice.CountOfConnected = ConnectedDevice.CountOfConnected + 1;
			EndIf;
			
		EndDo;
		
	ElsIf  DeviceIdentifier <> Undefined AND AlertOnConnect <> Undefined Then
		ErrorDescription =  NStr("en = 'The selected peripheral can not be used for connection. Specify other device.'; ru = 'Выбранное устройство не может использоваться для подключения. Укажите другое устройство.';pl = 'Wybrane urządzenie peryferyjne nie może być używane do połączenia. Określ inne urządzenie.';es_ES = 'El periférico seleccionado no puede utilizarse para conectar. Especificar otro dispositivo.';es_CO = 'El periférico seleccionado no puede utilizarse para conectar. Especificar otro dispositivo.';tr = 'Seçilen çevre birimi bağlantı için kullanılamaz. Diğer cihazı belirtin.';it = 'Il dispositivo selezionato non può essere utilizzato per la connessione. Si prega di inserire un dispositivo diverso.';de = 'Das ausgewählte Peripheriegerät kann nicht für die Verbindung verwendet werden. Anderes Gerät angeben.'");
		ExecutionResult = New Structure("Result, ErrorDetails", Result, ErrorDescription);
		ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
	EndIf;
	
EndProcedure

// Start disabling devices by equipment type.
//
Procedure StartDisconnectEquipmentByType(AlertOnDisconnect, ClientID, EETypes) Export
	
	StartDisconnectEquipment(AlertOnDisconnect, ClientID, EETypes, );
	
EndProcedure

//  Start disconnecting a peripheral defined by an identifier.
//
Procedure StartDisableEquipmentByIdidentifier(AlertOnDisconnect, ClientID, DeviceIdentifier) Export
	
	StartDisconnectEquipment(AlertOnDisconnect, ClientID, , DeviceIdentifier);
	
EndProcedure

Procedure StartDisconnectEquipmentEnd(ExecutionResult, Parameters) Export
	
	If ExecutionResult.Result Then
		
		Parameters.ConnectedDevice.CountOfConnected = 0;
		
		ArrayLineNumber = glPeripherals.PeripheralsConnectingParameters.Find(Parameters.ConnectedDevice);
		If ArrayLineNumber <> Undefined Then
			glPeripherals.PeripheralsConnectingParameters.Delete(ArrayLineNumber);
		EndIf;
		If Parameters.AlertOnDisconnect <> Undefined Then
			ErrorDescription = NStr("en = 'No errors.'; ru = 'Ошибок нет.';pl = 'Bez błędów.';es_ES = 'No hay errores.';es_CO = 'No hay errores.';tr = 'Hata yok.';it = 'Nessun errore.';de = 'Keine fehler.'");
			ExecutionResult = New Structure("Result, ErrorDetails", True, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnDisconnect, ExecutionResult);
		EndIf;
	Else
		// Inform user that a peripheral failed to be connected.
		If Parameters.AlertOnDisconnect <> Undefined Then
			ErrorDescription = NStr("en = 'An error occurred when disconnecting the ""%Description%"" device: %ErrorDescription% (%ErrorCode%)'; ru = 'При отключении устройства ""%Description%"" произошла ошибка: %ErrorDescription% (%ErrorCode%)';pl = 'Wystąpił błąd podczas odłączania ""%Description%"" urządzenia: %ErrorDescription% (%ErrorCode%)';es_ES = 'Ha ocurrido un error al desconectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';es_CO = 'Ha ocurrido un error al desconectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';tr = '""%Description%"" cihazının bağlantısı kesilirken hata oluştu: %ErrorDescription% (%ErrorCode%)';it = 'Si è verificato un errore durante la disconnessione del ""%Description%"" device: %ErrorDescription% (%ErrorCode%)';de = 'Beim Trennen der ""%Description%"" Vorrichtung ist ein Fehler aufgetreten: %ErrorDescription%(%ErrorCode%)'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , Parameters.ConnectedDevice.Description);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Parameters.Output_Parameters[1]);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Parameters.Output_Parameters[0]);
			ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnDisconnect, ExecutionResult);
		EndIf;
	EndIf;

EndProcedure

Procedure StartDisconnectEquipmentGettingDriverObjectEnd(DriverObject, Parameters) Export
	
	If DriverObject = Undefined Then
		
		If Parameters.AlertOnDisconnect <> Undefined Then
			// Error message prompting that the driver can not be imported.
			ErrorDescription = NStr("en = '%Description%: Cannot export the peripheral driver.
			                        |Check if the driver is correctly installed and registered in the system.'; 
			                        |ru = '%Description%: Не удалось загрузить драйвер устройства.
			                        |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
			                        |pl = '%Description%: Nie można wyeksportować sterownika urządzenia peryferyjnego.
			                        |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
			                        |es_ES = '%Description%: No se puede exportar el driver de periféricos.
			                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                        |es_CO = '%Description%: No se puede exportar el driver de periféricos.
			                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                        |tr = '%Description%: Çevre birimi sürücüsü dışa aktarılamıyor.
			                        |Sürücünün sistemde doğru şekilde kurulduğundan ve kayıtlı olduğundan emin olun.';
			                        |it = '%Description%: Non è possibile esportare il driver della periferica.
			                        |Controllare se il driver è installato correttamente e registrato nel sistema.';
			                        |de = '%Description%: Der Peripherietreiber kann nicht exportiert werden.
			                        |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", Parameters.ConnectedDevice.Description);
			ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnDisconnect, ExecutionResult);
		EndIf;
		
	Else
		Notification = New NotifyDescription("StartDisconnectEquipmentEnd", ThisObject, Parameters);
		Parameters.DriverHandler.StartDisableDevice(Notification, DriverObject, 
			 Parameters.ConnectedDevice.Parameters,  Parameters.ConnectedDevice.ConnectionParameters, Undefined);
	EndIf;
	
EndProcedure

// Function enables devices by the equipment type.
// 
Procedure StartDisconnectEquipment(AlertOnDisconnect, ClientID, EETypes = Undefined, DeviceIdentifier = Undefined)
	
	If glPeripherals.PeripheralsConnectingParameters <> Undefined Then
		CountDevices = glPeripherals.PeripheralsConnectingParameters.Count();
		For IndexOf = 1 To CountDevices Do
			
			ConnectedDevice = glPeripherals.PeripheralsConnectingParameters[CountDevices - IndexOf];
			TypeNameOfSoftware = EquipmentManagerClientReUse.GetEquipmentTypeName(ConnectedDevice.EquipmentType);
			ClientConnection = ConnectedDevice.Clients.Find(ClientID);
			If ClientConnection <> Undefined  AND (EETypes = Undefined Or EETypes.Find(TypeNameOfSoftware) <> Undefined)
			   AND (DeviceIdentifier = Undefined  Or ConnectedDevice.Ref = DeviceIdentifier)Then
				
				If ConnectedDevice.CountOfConnected = 1 Then
					
					DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ConnectedDevice.DriverHandler, Not ConnectedDevice.AsConfigurationPart);
					If DriverHandler = Undefined Then
						// Report an error: can not connect the handler.
						If AlertOnDisconnect <> Undefined Then
							ErrorDescription = NStr("en = 'Cannot connect the driver handler.'; ru = 'Не удалось подключить обработчик драйвера.';pl = 'Nie można podłączyć sterownika obsługi.';es_ES = 'No se puede conectar el manipulador del driver.';es_CO = 'No se puede conectar el manipulador del driver.';tr = 'Sürücü işleyicisi bağlanılamıyor.';it = 'Non è possibile collegarsi al gestore del driver.';de = 'Der Treiber-Handler kann nicht verbunden werden.'");
							ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
							ExecuteNotifyProcessing(AlertOnDisconnect, ExecutionResult);
						EndIf;
					Else
						// Split on asynchronous and synchronous calls.
						If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
							// Asynchronous calls
							CommandParameters = New Structure("ConnectedDevice, AlertOnDisconnect, DriverHandler", ConnectedDevice, AlertOnDisconnect, DriverHandler);
							Notification = New NotifyDescription("StartDisconnectEquipmentGettingDriverObjectEnd", ThisObject, CommandParameters);
							StartReceivingDriverObject(Notification, ConnectedDevice);
						Else
							DriverObject = GetDriverObject(ConnectedDevice);
							If DriverObject = Undefined Then
								If AlertOnDisconnect <> Undefined Then
									// Error message prompting that the driver can not be imported.
									ErrorDescription = NStr("en = '%Description%: Cannot export the peripheral driver.
									                        |Check if the driver is correctly installed and registered in the system.'; 
									                        |ru = '%Description%: Не удалось загрузить драйвер устройства.
									                        |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
									                        |pl = '%Description%: Nie można wyeksportować sterownika urządzenia peryferyjnego.
									                        |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
									                        |es_ES = '%Description%: No se puede exportar el driver de periféricos.
									                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
									                        |es_CO = '%Description%: No se puede exportar el driver de periféricos.
									                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
									                        |tr = '%Description%: Çevre birimi sürücüsü dışa aktarılamıyor.
									                        |Sürücünün sistemde doğru şekilde kurulduğundan ve kayıtlı olduğundan emin olun.';
									                        |it = '%Description%: Non è possibile esportare il driver della periferica.
									                        |Controllare se il driver è installato correttamente e registrato nel sistema.';
									                        |de = '%Description%: Der Peripherietreiber kann nicht exportiert werden.
									                        |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
									ErrorDescription = StrReplace(ErrorDescription, "%Description%",ConnectedDevice.Description);
									ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
									ExecuteNotifyProcessing(AlertOnDisconnect, ExecutionResult);
								EndIf;
							Else
								Output_Parameters = Undefined;
								Result = DriverHandler.DisableDevice(DriverObject, ConnectedDevice.Parameters, ConnectedDevice.ConnectionParameters, Output_Parameters);
								If Not Result Then
									// Inform user that a peripheral failed to be connected.
									If AlertOnDisconnect <> Undefined Then
										ErrorDescription = NStr("en = 'An error occurred when disconnecting the ""%Description%"" device: %ErrorDescription% (%ErrorCode%)'; ru = 'При отключении устройства ""%Description%"" произошла ошибка: %ErrorDescription% (%ErrorCode%)';pl = 'Wystąpił błąd podczas odłączania ""%Description%"" urządzenia: %ErrorDescription% (%ErrorCode%)';es_ES = 'Ha ocurrido un error al desconectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';es_CO = 'Ha ocurrido un error al desconectar el dispositivo ""%Description%"": %ErrorDescription% (%ErrorCode%)';tr = '""%Description%"" cihazının bağlantısı kesilirken hata oluştu: %ErrorDescription% (%ErrorCode%)';it = 'Si è verificato un errore durante la disconnessione del ""%Description%"" device: %ErrorDescription% (%ErrorCode%)';de = 'Beim Trennen der ""%Description%"" Vorrichtung ist ein Fehler aufgetreten: %ErrorDescription%(%ErrorCode%)'");
										ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , ConnectedDevice.Description);
										ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
										ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Output_Parameters[0]);
										ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
										ExecuteNotifyProcessing(AlertOnDisconnect, ExecutionResult);
									EndIf;
								Else
									ConnectedDevice.CountOfConnected = 0;
								EndIf;
								
								ArrayLineNumber = glPeripherals.PeripheralsConnectingParameters.Find(ConnectedDevice);
								If ArrayLineNumber <> Undefined Then
									glPeripherals.PeripheralsConnectingParameters.Delete(ArrayLineNumber);
								EndIf;
								
								If AlertOnDisconnect <> Undefined Then
									ErrorDescription = NStr("en = 'No errors.'; ru = 'Ошибок нет.';pl = 'Bez błędów.';es_ES = 'No hay errores.';es_CO = 'No hay errores.';tr = 'Hata yok.';it = 'Nessun errore.';de = 'Keine fehler.'");
									ExecutionResult = New Structure("Result, ErrorDetails", True, ErrorDescription);
									ExecuteNotifyProcessing(AlertOnDisconnect, ExecutionResult);
								EndIf;
								
							EndIf;
							
						EndIf;
					EndIf;
					
				Else
					ConnectedDevice.CountOfConnected = ConnectedDevice.CountOfConnected - 1;
					ConnectedDevice.Clients.Delete(ClientConnection);
				EndIf;
			EndIf;
			
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion   

#Region ProceduresAndFunctionsEnableDisableEquipmentInForm

// Connects required peripheral types on opening the form.
//
// Parameters:
// Form - ClientApplicationForm
// SupportedPeripheralTypes - String
// 	Contains peripherals types list separated by commas.
//
Function ConnectEquipmentOnOpenForms(Form, SupportedPeripheralTypes) Export
	
	EquipmentConnected = True;
	
	Form.SupportedPeripheralTypes = SupportedPeripheralTypes;
	
	If Form.UsePeripherals AND RefreshClientWorkplace() Then

		ErrorDescription = "";
		
		EquipmentConnected = ConnectEquipmentByType(
			Form.UUID,
			ConvertStringToArrayList(Form.SupportedPeripheralTypes),
			ErrorDescription);
		
		If Not EquipmentConnected Then
			
			MessageText = NStr("en = 'An error occurred while
			                   |connecting peripherals: ""%ErrorDetails%"".'; 
			                   |ru = 'При подключении оборудования
			                   |произошла ошибка: ""%ErrorDetails%"".';
			                   |pl = 'Wystąpił błąd podczas
			                   |podłączania urządzeń peryferyjnych: ""%ErrorDetails%"".';
			                   |es_ES = 'Ha ocurrido un error al
			                   |conectar los periféricos: ""%ErrorDetails%"".';
			                   |es_CO = 'Ha ocurrido un error al
			                   |conectar los periféricos: ""%ErrorDetails%"".';
			                   |tr = 'Çevre birimleri bağlanırken
			                   |hata oluştu: ""%ErrorDetails%"".';
			                   |it = 'Quando si collega la periferica"
"si è verificato un errore: ""%ErrorDetails%"".';
			                   |de = 'Beim
			                   |Anschließen der Peripherie ist ein Fehler aufgetreten: ""%ErrorDetails%"".'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
	Return EquipmentConnected; // Shows that an error occurs while enabling equipment.
	
EndFunction

// Disconnects required peripheral types on closing the form.
//
Function DisconnectEquipmentOnCloseForms(Form) Export
	
	Return DisableEquipmentByType(
				Form.UUID,
				ConvertStringToArrayList(Form.SupportedPeripheralTypes));
	
EndFunction

// Start enabling required devices types during form opening
//
// Parameters:
// Form - ClientApplicationForm
// SupportedPeripheralTypes - String
// 	Contains peripherals types list separated by commas.
//
Procedure StartConnectingEquipmentOnFormOpen(AlertOnConnect, Form, SupportedPeripheralTypes) Export
	
	Form.SupportedPeripheralTypes = SupportedPeripheralTypes;
	
	If Form.UsePeripherals AND RefreshClientWorkplace() Then
		StartEnableEquipmentByType(AlertOnConnect,
											Form.UUID,
											ConvertStringToArrayList(Form.SupportedPeripheralTypes));
	EndIf;
	
EndProcedure

// Start disconnecting peripherals by type on closing the form.
//
Procedure StartDisablingEquipmentOnCloseForm(AlertOnDisconnect, Form) Export
	
	StartDisconnectEquipmentByType(AlertOnDisconnect, 
										Form.UUID, 
										ConvertStringToArrayList(Form.SupportedPeripheralTypes));
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForWorkWithPeripherals

// Directs command to the
// responsible driver handler (according to the specified handler value in the "Identifier" incoming parameter).
Function RunCommand(ID, Command, InputParameters, Output_Parameters, Timeout = -1) Export
	
	Result = False;
	
	// Search for enabled device.
	ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, ID);
	
	If ConnectedDevice <> Undefined Then
		// Getting a driver object
		DriverObject = GetDriverObject(ConnectedDevice);
		If DriverObject = Undefined Then
			
			// Error message prompting that the driver can not be imported.
			Output_Parameters = New Array();
			ErrorDescription = NStr("en = '""%Description%"": Cannot export the peripheral driver.
			                        |Check if the driver is correctly installed and registered in the system.'; 
			                        |ru = '%Description%: Не удалось загрузить драйвер устройства.
			                        |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
			                        |pl = '""%Description%"": Nie można wyeksportować sterownika urządzenia peryferyjnego.
			                        |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
			                        |es_ES = '""%Description%"": No se puede exportar el driver de periféricos.
			                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                        |es_CO = '""%Description%"": No se puede exportar el driver de periféricos.
			                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                        |tr = '""%Description%"": Çevre birimi sürücüsü dışa aktarılamıyor.
			                        |Sürücünün sistemde doğru şekilde kurulduğundan ve kayıtlı olduğundan emin olun.';
			                        |it = '%Description%: Non è possibile esportare il driver della periferica.
			                        |Controllare se il driver è installato correttamente e registrato nel sistema.';
			                        |de = '""%Description%"": Der Peripherietreiber kann nicht exportiert werden.
			                        |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
			Output_Parameters.Add(999);
			Output_Parameters.Add(ErrorDescription);
			
		Else
			
			Parameters            = ConnectedDevice.Parameters;
			ConnectionParameters = ConnectedDevice.ConnectionParameters;
			
			DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ConnectedDevice.DriverHandler, Not ConnectedDevice.AsConfigurationPart);
			
			If DriverHandler = Undefined Then
				// Error message prompting that the driver can not be imported.
				Output_Parameters = New Array();
				MessageText = NStr("en = 'Cannot connect the driver handler.'; ru = 'Не удалось подключить обработчик драйвера.';pl = 'Nie można podłączyć sterownika obsługi.';es_ES = 'No se puede conectar el manipulador del driver.';es_CO = 'No se puede conectar el manipulador del driver.';tr = 'Sürücü işleyicisi bağlanılamıyor.';it = 'Non è possibile collegarsi al gestore del driver.';de = 'Der Treiber-Handler kann nicht verbunden werden.'");
				Output_Parameters.Add(999);
				Output_Parameters.Add(MessageText);
				Output_Parameters.Add(NStr("en = 'Not set'; ru = 'Не установлен';pl = 'Nieustawiony';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non impostato';de = 'Nicht eingestellt'"));
			Else
				// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
				If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
					DriverHandler = PeripheralsUniversalDriverClient;
				EndIf;
				// Call command execution method from handler.
				Result = DriverHandler.RunCommand(Command,
					InputParameters,
					Output_Parameters,
					DriverObject,
					Parameters,
					ConnectionParameters); 
			EndIf
			
		EndIf;
	Else
		// Report an error saying that the device is not connected.
		Output_Parameters = New Array();
		MessageText = NStr("en = 'Device is not connected. Before performing the operation the device should be connected.'; ru = 'Устройство не подключено. Перед выполнением операции устройство должно быть подключено.';pl = 'Urządzenie nie jest podłączone. Przed wykonaniem operacji urządzenie należy podłączyć.';es_ES = 'Dispositivo no está conectado. Antes de realizar la operación hay que conectar el dispositivo.';es_CO = 'Dispositivo no está conectado. Antes de realizar la operación hay que conectar el dispositivo.';tr = 'Cihaz bağlı değil. İşlem gerçekleştirilmeden önce cihaz bağlanmalıdır.';it = 'Il dispositivo non è collegato. Prima di eseguire l''operazione, il dispositivo deve essere collegato.';de = 'Gerät ist nicht verbunden. Vor der Durchführung der Operation sollte das Gerät angeschlossen werden.'");
		Output_Parameters.Add(999);
		Output_Parameters.Add(MessageText);
	EndIf;

	Return Result;

EndFunction

// Performs an additional command to the driver not requiring preliminary device connection in system.
//
Function RunAdditionalCommand(Command, InputParameters, Output_Parameters, ID, Parameters) Export
	
	Result = False;
	
	// Search for enabled device.
	ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, ID);

	If ConnectedDevice = Undefined Then
		
		EquipmentData = EquipmentManagerServerCall.GetDeviceData(ID);
		
		TempConnectionParameters = New Structure();
		TempConnectionParameters.Insert("EquipmentType", EquipmentData.EquipmentTypeName);
		
		DriverObject = GetDriverObject(EquipmentData);
		
		If DriverObject = Undefined Then
			
			// Error message prompting that the driver can not be imported.
			Output_Parameters = New Array();
			MessageText = NStr("en = 'Unable to import device driver.
			                   |Check if the driver is correctly installed and registered in the system.'; 
			                   |ru = 'Не удалось загрузить драйвер устройства.
			                   |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
			                   |pl = 'Nie można zaimportować sterownika urządzenia.
			                   |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
			                   |es_ES = 'No se puede importar el driver del dispositivo.
			                   |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                   |es_CO = 'No se puede importar el driver del dispositivo.
			                   |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
			                   |tr = 'Çevre birimi sürücüsü içe aktarılamıyor.
			                   | Sürücünün sistemde doğru şekilde kurulup kurulmadığını ve kayıtlı olup olmadığını kontrol edin.';
			                   |it = 'Non in grado di importare i driver del dispositivo.
			                   |Controllare se il driver è correttamente installato e registrato nel sistema.';
			                   |de = 'Der Gerätetreiber konnte nicht importiert werden.
			                   |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
			Output_Parameters.Add(999);
			Output_Parameters.Add(MessageText);
			Output_Parameters.Add(NStr("en = 'Not set'; ru = 'Не установлен';pl = 'Nieustawiony';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non impostato';de = 'Nicht eingestellt'"));
			
		Else
			
			DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(EquipmentData.DriverHandler, Not EquipmentData.AsConfigurationPart);
		
			If DriverHandler = Undefined Then
				// Error message prompting that the driver can not be imported.
				Output_Parameters = New Array();
				MessageText = NStr("en = 'Cannot connect the driver handler.'; ru = 'Не удалось подключить обработчик драйвера.';pl = 'Nie można podłączyć sterownika obsługi.';es_ES = 'No se puede conectar el manipulador del driver.';es_CO = 'No se puede conectar el manipulador del driver.';tr = 'Sürücü işleyicisi bağlanılamıyor.';it = 'Non è possibile collegarsi al gestore del driver.';de = 'Der Treiber-Handler kann nicht verbunden werden.'");
				Output_Parameters.Add(999);
				Output_Parameters.Add(MessageText);
				Output_Parameters.Add(NStr("en = 'Not set'; ru = 'Не установлен';pl = 'Nieustawiony';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non impostato';de = 'Nicht eingestellt'"));
			Else
				// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
				If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
					DriverHandler = PeripheralsUniversalDriverClient;
				EndIf;
				Result = DriverHandler.RunCommand(Command,
					InputParameters,
					Output_Parameters,
					DriverObject,
					Parameters,
					TempConnectionParameters);
					If Not Result Then
						Output_Parameters.Add(NStr("en = 'Set'; ru = 'установки';pl = 'Ustaw';es_ES = 'Establecer';es_CO = 'Establecer';tr = 'Ayarla';it = 'Imposta';de = 'Einstellen'"));
					EndIf;
			EndIf
				
		EndIf;
	Else
		// Report an error saying that the device is enabled.
		Output_Parameters = New Array();
		MessageText = NStr("en = 'The device is connected. Before you start, disconnect the device.'; ru = 'Устройство подключено. Перед выполнением операции устройство должно быть отключено.';pl = 'Urządzenie jest połączone. Zanim zaczniesz wykonanie operacji, odłącz urządzenie.';es_ES = 'El dispositivo está conectado. Antes de empezar, desconectar el dispositivo.';es_CO = 'El dispositivo está conectado. Antes de empezar, desconectar el dispositivo.';tr = 'Cihaz bağlandı. Başlamadan önce, cihazın bağlantısını kesin.';it = 'Il dispositivo è collegato. Prima di eseguire l''operazione, il dispositivo deve essere spento.';de = 'Das Gerät ist verbunden. Bevor Sie beginnen, trennen Sie das Gerät.'");
		Output_Parameters.Add(999);
		Output_Parameters.Add(MessageText);
		Output_Parameters.Add(NStr("en = 'Set'; ru = 'установки';pl = 'Ustaw';es_ES = 'Establecer';es_CO = 'Establecer';tr = 'Ayarla';it = 'Imposta';de = 'Einstellen'"));
	EndIf;
	
	Return Result;
	
EndFunction

// End execution of the additional driver command to driver not requiring
// preliminary device connection in system.
//
Procedure StartAdditionalCommandExecutionEnd(DriverObject, CommandParameters) Export
	
	If DriverObject = Undefined Then
		// Error message prompting that the driver can not be imported.
		ErrorText = NStr("en = 'Unable to import device driver.
		                 |Check if the driver is correctly installed and registered in the system.'; 
		                 |ru = 'Не удалось загрузить драйвер устройства.
		                 |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
		                 |pl = 'Nie można zaimportować sterownika urządzenia.
		                 |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
		                 |es_ES = 'No se puede importar el driver del dispositivo.
		                 |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
		                 |es_CO = 'No se puede importar el driver del dispositivo.
		                 |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
		                 |tr = 'Çevre birimi sürücüsü içe aktarılamıyor.
		                 | Sürücünün sistemde doğru şekilde kurulup kurulmadığını ve kayıtlı olup olmadığını kontrol edin.';
		                 |it = 'Non in grado di importare i driver del dispositivo.
		                 |Controllare se il driver è correttamente installato e registrato nel sistema.';
		                 |de = 'Der Gerätetreiber konnte nicht importiert werden.
		                 |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
		Output_Parameters = New Array();
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorText);
		Output_Parameters.Add(NStr("en = 'Not set'; ru = 'Не установлен';pl = 'Nieustawiony';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non impostato';de = 'Nicht eingestellt'"));
		ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
		ExecuteNotifyProcessing(CommandParameters.AlertOnEnd, ExecutionResult);
	Else
		
		DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(CommandParameters.EquipmentData.DriverHandler, Not CommandParameters.EquipmentData.AsConfigurationPart);
		
		If DriverHandler = Undefined Then
			// Inform that the driver handler failed to be connected.
			ErrorText = NStr("en = 'Cannot connect the driver handler.'; ru = 'Не удалось подключить обработчик драйвера.';pl = 'Nie można podłączyć sterownika obsługi.';es_ES = 'No se puede conectar el manipulador del driver.';es_CO = 'No se puede conectar el manipulador del driver.';tr = 'Sürücü işleyicisi bağlanılamıyor.';it = 'Non è possibile collegarsi al gestore del driver.';de = 'Der Treiber-Handler kann nicht verbunden werden.'");
			Output_Parameters = New Array();
			Output_Parameters.Add(999);
			Output_Parameters.Add(ErrorText);
			Output_Parameters.Add(NStr("en = 'Not set'; ru = 'Не установлен';pl = 'Nieustawiony';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non impostato';de = 'Nicht eingestellt'"));
			ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
			ExecuteNotifyProcessing(CommandParameters.AlertOnEnd, ExecutionResult);
		Else
			TempConnectionParameters = New Structure();
			TempConnectionParameters.Insert("EquipmentType", CommandParameters.EquipmentData.EquipmentTypeName);
			
			If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
				DriverHandler.StartCommandExecution(CommandParameters.AlertOnEnd, CommandParameters.Command, CommandParameters.InputParameters,
					DriverObject, CommandParameters.Parameters, TempConnectionParameters);
			Else
				Output_Parameters = Undefined;
				Result = DriverHandler.RunCommand(CommandParameters.Command, CommandParameters.InputParameters,
					Output_Parameters, DriverObject, CommandParameters.Parameters, TempConnectionParameters);
				If Not Result Then
					Output_Parameters.Add(NStr("en = 'Set'; ru = 'установки';pl = 'Ustaw';es_ES = 'Establecer';es_CO = 'Establecer';tr = 'Ayarla';it = 'Imposta';de = 'Einstellen'"));
				EndIf;
				ExecutionResult = New Structure("Result, Output_Parameters", Result, Output_Parameters);
				ExecuteNotifyProcessing(CommandParameters.AlertOnEnd, ExecutionResult);
			EndIf;
		EndIf
	EndIf;
	
EndProcedure

// Start executing additional command to driver not requiring preliminary device connection in system.
//
Procedure StartExecuteAdditionalCommand(AlertOnEnd, Command, InputParameters, ID, Parameters) Export
	
	// Search for enabled device.
	ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, ID);
	                                                       
	If ConnectedDevice = Undefined Then
		EquipmentData = EquipmentManagerServerCall.GetDeviceData(ID);
		CommandParameters = New Structure();
		CommandParameters.Insert("Command"          , Command);
		CommandParameters.Insert("InputParameters"  , InputParameters);
		CommandParameters.Insert("Parameters"       , Parameters);
		CommandParameters.Insert("EquipmentData"    , EquipmentData);
		CommandParameters.Insert("AlertOnEnd"       , AlertOnEnd);
		Notification = New NotifyDescription("StartAdditionalCommandExecutionEnd", ThisObject, CommandParameters);
		StartReceivingDriverObject(Notification, EquipmentData);
	Else
		// Report an error saying that the device is enabled.
		ErrorText = NStr("en = 'The device is connected. Before you start, disconnect the device.'; ru = 'Устройство подключено. Перед выполнением операции устройство должно быть отключено.';pl = 'Urządzenie jest połączone. Zanim zaczniesz wykonanie operacji, odłącz urządzenie.';es_ES = 'El dispositivo está conectado. Antes de empezar, desconectar el dispositivo.';es_CO = 'El dispositivo está conectado. Antes de empezar, desconectar el dispositivo.';tr = 'Cihaz bağlandı. Başlamadan önce, cihazın bağlantısını kesin.';it = 'Il dispositivo è collegato. Prima di eseguire l''operazione, il dispositivo deve essere spento.';de = 'Das Gerät ist verbunden. Bevor Sie beginnen, trennen Sie das Gerät.'");
		Output_Parameters = New Array();
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorText);
		Output_Parameters.Add(NStr("en = 'Set'; ru = 'установки';pl = 'Ustaw';es_ES = 'Establecer';es_CO = 'Establecer';tr = 'Ayarla';it = 'Imposta';de = 'Einstellen'"));
		ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
		ExecuteNotifyProcessing(AlertOnEnd, ExecutionResult);
	EndIf;
	
EndProcedure

#EndRegion

#Region HelperProceduresAndFunctions

// Function called during the system work start.
// Prepares mechanism data.
Function OnStart() Export

	If glPeripherals = Undefined Then
		glPeripherals = New Structure("PeripheralsDrivers,
												|PeripheralsConnectingParameters,
												|LastSlipReceipt,
												|DMDevicesTable,
												|ManagerDriverParameters",
												 New Map(),
												 New Array(),
												 "",
												 New Structure(),
												 New Structure());
	EndIf;
	
#If Not WebClient Then
	ResetMarkedDrivers();
#EndIf
	
EndFunction

// Function called during the system work start.
// Prepares mechanism data.
Function BeforeExit() Export
	
	DisableAllEquipment();
	
EndFunction

// Set equipment.
// 
Procedure ExecuteEquipmentSetup(ID) Export

	Result = True;
	
	DataDevice = EquipmentManagerClientReUse.GetDeviceData(ID);
	FormParameters = New Structure("EquipmentParameters", DataDevice.Parameters);
	FormParameters.Insert("ID", ID);
	FormParameters.Insert("HardwareDriver", DataDevice.HardwareDriver);  
	
	SettingsForm = "StandardPeripheralsDriverSettings";
	
	DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(DataDevice.DriverHandler, Not DataDevice.AsConfigurationPart);
		
	If Not DriverHandler = PeripheralsUniversalDriverClient AND 
		Not DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
		SettingsForm = EquipmentManagerClientReUse.GetParametersSettingFormName(String(DataDevice.DriverHandler));
	EndIf;
		
	If Not IsBlankString(SettingsForm) Then
		Handler = New NotifyDescription("ExecuteEquipmentSettingEnd", ThisObject);
		OpenForm("CommonForm." + SettingsForm, FormParameters,,,  ,, Handler, FormWindowOpeningMode.LockWholeInterface);
	Else
		CommonClientServer.MessageToUser(NStr("en = 'An error occurred when initializing the driver setting form.'; ru = 'Произошла ошибка инициализации формы настройки драйвера.';pl = 'Wystąpił błąd podczas inicjowania formularza ustawień sterownika.';es_ES = 'Ha ocurrido un error al iniciar el formulario de la configuración del driver.';es_CO = 'Ha ocurrido un error al iniciar el formulario de la configuración del driver.';tr = 'Sürücü ayar formu başlatılırken bir hata oluştu.';it = 'Si è verificato un errore durante l''inizializzazione del modulo di configurazione del driver.';de = 'Beim Initialisieren des Formulars für die Treibereinstellung ist ein Fehler aufgetreten.'")); 
	EndIf;
	
EndProcedure

// End equipment setting.
//
Procedure ExecuteEquipmentSettingEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		CompletionResult = False;
		If Result.Property("ID") AND Result.Property("EquipmentParameters") Then
			CompletionResult = EquipmentManagerServerCall.SaveDeviceParameters(Result.ID, Result.EquipmentParameters);
		EndIf;
		
		If CompletionResult Then 
			RefreshReusableValues();
		Else
			ErrorInfo = NStr("en = 'Cannot save the device parameters.'; ru = 'Не удалось сохранить параметры устройства.';pl = 'Zapis parametrów urządzenia nie powiódł się.';es_ES = 'No se puede guardar los parámetros del dispositivo.';es_CO = 'No se puede guardar los parámetros del dispositivo.';tr = 'Cihaz parametreleri kaydedilemiyor.';it = 'Impossibile salvare i parametri del dispositivo.';de = 'Die Geräteparameter können nicht gespeichert werden.'");
			CommonClientServer.MessageToUser(ErrorInfo);
		EndIf;
		
	EndIf;
	
EndProcedure

// Saves user settings of peripherals.
//
Procedure SaveUserSettingsOfPeripherals(SettingsList) Export

	EquipmentManagerServerCall.SaveUserSettingsOfPeripherals(SettingsList);

EndProcedure

// Procedure generates the delay of the specified duration.
//
// Parameters:
//  Time - <Number>
//        - Delay duration in seconds.
//
Procedure Pause(Time) Export

	CompletionTime = CommonClient.SessionDate() + Time;
	While CommonClient.SessionDate() < CompletionTime Do
	EndDo;

EndProcedure

// Cuts the passed row by the field length if the field is too short - adds spaces.
//
Function ConstructField(Text, FieldLenght) Export
	
	TextFull = Left(Text, FieldLenght);
	While StrLen(TextFull) < FieldLenght Do
		TextFull = TextFull + " ";
	EndDo;
	
	Return TextFull;
	
EndFunction

// Convert row list to array.
//
Function ConvertStringToArrayList(Source) Export
	
	IntermediateStructure = New Structure(Source);
	Receiver = New Array;
	
	For Each KeyAndValue In IntermediateStructure Do
		Receiver.Add(KeyAndValue.Key);
	EndDo;
	
	Return Receiver;
	
EndFunction

// Returns slip check template by the template name.
//
Function GetSlipReceipt(TemplateName, SlipReceiptWidth, Parameters, PINAuthorization = False) Export

	Return EquipmentManagerClientReUse.GetSlipReceipt(TemplateName, SlipReceiptWidth, Parameters, PINAuthorization);

EndFunction

Procedure BeginInstallFileSystemExtensionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		BeginInstallFileSystemExtension();
	EndIf;
	
EndProcedure

Procedure BeginEnableExtensionFileOperationsEnd(Attached, AdditionalParameters) Export
	
	If Not Attached AND AdditionalParameters.OfferInstallation Then
		Notification = New NotifyDescription("BeginInstallFileSystemExtensionEnd", ThisObject, AdditionalParameters);
		MessageText = NStr("en = 'To continue, you need to install an extension for 1C:Enterprise web client. Install?'; ru = 'Для продолжении работы необходимо установить расширение для веб-клиента ""1С:Предприятие"". Установить?';pl = 'Aby kontynuować, musisz zainstalować rozszerzenie dla klienta webowego 1C:Enterprise. Zainstalować?';es_ES = 'Para continuar, usted necesita instalar una extensión para el cliente web de la 1C:Empresa. ¿Instalar?';es_CO = 'Para continuar, usted necesita instalar una extensión para el cliente web de la 1C:Empresa. ¿Instalar?';tr = 'Devam edebilmek için 1C:Enterprise web istemcisi için bir uzantı yüklemeniz gerekiyor. Uzantı yüklensin mi?';it = 'Per proseguirem dovete installare una estensione per web-client di 1C:Enterprise. Installare?';de = 'Um fortzufahren, müssen Sie eine Erweiterung für 1C:Enterprise Web Client installieren. Installieren?'");
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo); 
	EndIf;
	
	If AdditionalParameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, Attached);
	EndIf
	
EndProcedure

// Check if extension of work with Files is available.
// 
Procedure CheckFileOperationsExtensionAvailability(AlertOnEnd, OfferInstallation = True) Export
	
	#If Not WebClient Then
	// The extension is always enabled in thin and thick client.
	ExecuteNotifyProcessing(AlertOnEnd, True);
	Return;
	#EndIf
	
	AdditionalParameters = New Structure("AlertOnEnd, OfferSetting", AlertOnEnd, OfferInstallation);
	Notification = New NotifyDescription("BeginEnableExtensionFileOperationsEnd", ThisObject, AdditionalParameters);
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

// End selecting driver file.
//
Procedure DriverFileChoiceEnd(SelectedFiles, Parameters) Export
	
	If TypeOf(SelectedFiles) = Type("Array") AND SelectedFiles.Count() > 0 
		AND Parameters.AlertOnSelection <> Undefined Then
		ExecuteNotifyProcessing(Parameters.AlertOnSelection, SelectedFiles[0]);
	EndIf;
	
EndProcedure

// The function starts selecting a driver file for further import.
//
Procedure StartDriverFileSelection(AlertOnSelection) Export 
	
	Result = False;
	FullFileName = "";
	
	FileOpeningDialog = New FileDialog(FileDialogMode.Open);
	FileOpeningDialog.Multiselect = False;
	FileOpeningDialog.Title = NStr("en = 'Select a driver file'; ru = 'Выберите файл драйвера';pl = 'Wybierz plik sterownika';es_ES = 'Seleccionar un archivo del driver';es_CO = 'Seleccionar un archivo del driver';tr = 'Bir sürücü dosyası seçin';it = 'Selezionare file driver';de = 'Wählen Sie eine Treiberdatei'");
	FileOpeningDialog.Filter = NStr("en = 'Driver file'; ru = 'Файл драйвера';pl = 'Plik sterownika';es_ES = 'Archivo del driver';es_CO = 'Archivo del driver';tr = 'Sürücü dosyası';it = 'File del driver';de = 'Treiberdatei'") + ?(EquipmentManagerClientReUse.IsLinuxClient(), "(*.zip)|*.zip", "(*.zip, *.exe)| *.zip; *.exe");  
	
	Parameters = New Structure("AlertOnSelection", AlertOnSelection);
	Notification = New NotifyDescription("DriverFileChoiceEnd", ThisObject, Parameters);
	
	FileOpeningDialog.Show(Notification);
	
EndProcedure

// End selecting a file
//
Procedure StartFileSelectionEndExtension(IsSet, AdditionalParameters) Export
	
	If IsSet Then
		Dialog = New FileDialog(FileDialogMode.Open);
		Dialog.Multiselect = False;
		Dialog.FullFileName = AdditionalParameters.FileName;
		Dialog.Show(AdditionalParameters.AlertOnSelection);
	EndIf;
	
EndProcedure

// The function starts a file selection.
//
Procedure StartFileSelection(AlertOnSelection, Val FileName) Export
	
	CommandParameters = New Structure("AlertOnSelection, FileName", AlertOnSelection, FileName);
	Notification = New NotifyDescription("StartFileSelectionEndExtension", ThisObject, CommandParameters);
	CheckFileOperationsExtensionAvailability(Notification);
	StandardProcessing = False;
	
EndProcedure

// The procedure selects a peripheral from the available ones associated with the current workplace.
//
Procedure OfferSelectDevice(SelectionNotification, EquipmentType, HeaderTextSelect, 
	NotConnectedMessage = "", MessageNotSelected = "", WithoutMessages = False, MessageText = "") Export
	
	If Not RefreshClientWorkplace() Then
		MessageText = NStr("en = 'First, you need to select the workplace of the current session peripherals.'; ru = 'Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.';pl = 'Najpierw trzeba wybrać miejsce pracy urządzeń peryferyjnych bieżącej sesji.';es_ES = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';es_CO = 'Primero, usted necesita seleccionar el lugar de trabajo de los periféricos de la sesión actual.';tr = 'İlk olarak, mevcut oturumdaki çevre birimlerinin çalışma alanını seçmeniz gerekir.';it = 'Innanzitutto è necessario selezionare la postazione di lavoro delle periferiche della sessione corrente.';de = 'Zuerst müssen Sie den Arbeitsplatz der aktuellen Sitzungsperipherie auswählen.'");
		If Not WithoutMessages Then
		      CommonClientServer.MessageToUser(MessageText);
		EndIf;
		Return;
	EndIf;
	
	ListOfAvailableDevices = EquipmentManagerServerCall.GetEquipmentList(EquipmentType);
	
	If ListOfAvailableDevices.Count() = 0 Then
		If Not IsBlankString(NOTConnectedMessage) Then
			If WithoutMessages Then
				MessageText = NotConnectedMessage;
			Else
				CommonClientServer.MessageToUser(NOTConnectedMessage);
			EndIf;
		EndIf;
	Else
		DeviceList = New ValueList();
		For Each Device In ListOfAvailableDevices Do
			DeviceList.Add(Device.Ref, Device.Description);
		EndDo;
		If DeviceList.Count() = 1 Then
			ID = DeviceList[0].Value;
			ExecuteNotifyProcessing(SelectionNotification, ID); 
		Else
			Context = New Structure;
			Context.Insert("NextAlert", SelectionNotification);
			Context.Insert("MessageNotSelected"  , ?(IsBlankString(MessageNotSelected), NotConnectedMessage, MessageNotSelected));
			Context.Insert("WithoutMessages"       , WithoutMessages);
			NotifyDescription = New NotifyDescription("OfferSelectDeviceEnd", ThisObject, Context);
			DeviceList.ShowChooseItem(NotifyDescription, HeaderTextSelect);
		EndIf;
	EndIf;
	
	Return;
	
EndProcedure

Procedure OfferSelectDeviceEnd(Result, Parameters) Export
	
	If Result = Undefined Then
		If Parameters <> Undefined Then
			If Parameters.WithoutMessages Then
				ExecuteNotifyProcessing(Parameters.NextAlert, Undefined);
			ElsIf Not IsBlankString(Parameters.MessageNotSelected) Then
				CommonClientServer.MessageToUser(Parameters.MessageNotSelected);
			EndIf;
		EndIf;
	Else
		If Parameters <> Undefined AND Parameters.NextAlert <> Undefined Then
			ID = Result.Value;
			ExecuteNotifyProcessing(Parameters.NextAlert, ID);
		EndIf;
	EndIf;
	
EndProcedure

// Function provides a dialog of workplace selection.
// 
Procedure OfferWorkplaceSelection(NotificationProcessing, ClientID = "") Export

	Result = False;
	Workplace = "";
	
	FormParameters = New Structure();
	FormParameters.Insert("ClientID", ClientID);
	
	OpenForm("Catalog.Peripherals.Form.WorkplaceChoiceForm", FormParameters,,,  ,, NotificationProcessing, FormWindowOpeningMode.LockWholeInterface);

EndProcedure

// End selecting workplace.
//
Procedure OfferWorkplaceSelectionEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") AND Result.Property("Workplace") Then 
		SetWorkplace(Result.Workplace);
	EndIf;
		
EndProcedure

// Function sets a workplace.
// 
Procedure SetWorkplace(Workplace) Export
	
	EquipmentManagerServerCall.SetClientWorkplace(Workplace);
	Notify("CurrentSessionWorkplaceChanged", Workplace);
	
EndProcedure

// Updates a computer name in a parameter of session "ClientWorkplace".
//
Function RefreshClientWorkplace() Export
	
	Result = True;
	
	Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	
	If Not ValueIsFilled(Workplace) Then
		SystemInfo = New SystemInfo();
		
		WorkplacesArray = EquipmentManagerClientReUse.FindWorkplacesById(Upper(SystemInfo.ClientID));
		If WorkplacesArray.Count() = 0 Then
			Parameters = New Structure;
			Parameters.Insert("ComputerName");
			Parameters.Insert("ClientID");
			
			#If Not WebClient Then
				Parameters.ComputerName = ComputerName();
			#EndIf
			
			Parameters.ClientID = Upper(SystemInfo.ClientID);
			Workplace = EquipmentManagerServerCall.CreateClientWorkplace(Parameters);
		Else
			Workplace = WorkplacesArray[0];
		EndIf;
		
	EndIf;
	
	If Result
		AND Workplace <> EquipmentManagerClientReUse.GetClientWorkplace() Then
		EquipmentManagerServerCall.SetClientWorkplace(Workplace);
		Notify("CurrentSessionWorkplaceChanged", Workplace);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region WorkWithElectronicScalesProceduresAndFunctions

// Receives weight from electronic scales.
// UUID - form identifiers.
// AlertOnGetWeight - alert on weighing end and weight pass.
//
Procedure StartWeightReceivingFromElectronicScales(AlertOnGetWeight, UUID) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnGetWeight);
	Context.Insert("UUID" , UUID);
	
	NotifyDescription = New NotifyDescription("StartWeightReceivingFromElectronicScalesEnd", ThisObject, Context);
	OfferSelectDevice(NotifyDescription, "ElectronicScales",
		NStr("en = 'Select electronic scales'; ru = 'Выберите электронные весы';pl = 'Wybierz wagi elektroniczne';es_ES = 'Seleccionar las escalas electrónicas';es_CO = 'Seleccionar las escalas electrónicas';tr = 'Elektronik tartı seçin';it = 'Selezionare bilance elettroniche';de = 'Elektronische Waagen auswählen'"), NStr("en = 'Electronic scales are not connected.'; ru = 'Электронные весы не подключены.';pl = 'Wagi elektroniczne nie są podłączone.';es_ES = 'Escalas electrónicas no están conectadas.';es_CO = 'Escalas electrónicas no están conectadas.';tr = 'Elektronik tartı bağlı değil.';it = 'Bilance elettroniche non collegate.';de = 'Elektronische Waagen sind nicht angeschlossen.'"), NStr("en = 'Electronic scales are not selected.'; ru = 'Электронные весы не выбраны.';pl = 'Wagi elektroniczne nie są wybrane.';es_ES = 'Escalas electrónicas no están seleccionadas.';es_CO = 'Escalas electrónicas no están seleccionadas.';tr = 'Elektronik tartı seçilmedi.';it = 'La bilancia elettronica non è selezionata.';de = 'Elektronische Waagen sind nicht ausgewählt.'"));
	
EndProcedure

// Procedure of weight receipt from electronic scales ending.
// 
Procedure StartWeightReceivingFromElectronicScalesEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	// Enable scales
	Result = ConnectEquipmentByID(Parameters.UUID, DeviceIdentifier, ErrorDescription);
	If Result Then  
		
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		// Attempt to get a weight
		Result = RunCommand(DeviceIdentifier, "GetWeight", InputParameters, Output_Parameters);    
		If Result Then
			Weight = Output_Parameters[0]; // Weight is received.
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, Weight);
			EndIf;
		Else
			MessageText = NStr("en = 'An error occurred while using electronic scales.
			                   |Additional description: |%AdditionalDetails%'; 
			                   |ru = 'При использовании электронных весов произошла ошибка.
			                   |Дополнительное описание: |%AdditionalDetails%';
			                   |pl = 'Wystąpił błąd podczas korzystania z wag elektronicznych.
			                   |Dodatkowy opis: |%AdditionalDetails%';
			                   |es_ES = 'Ha ocurrido un error al utilizar las escalas electrónicas.
			                   |Descripción adicional: |%AdditionalDetails%';
			                   |es_CO = 'Ha ocurrido un error al utilizar las escalas electrónicas.
			                   |Descripción adicional: |%AdditionalDetails%';
			                   |tr = 'Elektronik tartı kullanılırken hata oluştu.
			                   |Ek açıklama: %AdditionalDetails%';
			                   |it = 'Un errore si è registrato durante l''uso di bilance elettroniche.
			                   |Descrizione aggiuntiva: |%AdditionalDetails%';
			                   |de = 'Bei der Verwendung von elektronischen Waagen ist ein Fehler aufgetreten.
			                   |Zusätzliche Beschreibung: |%AdditionalDetails%'");
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
		// Disable scales
		DisableEquipmentById(Parameters.UUID, DeviceIdentifier);
		
	Else
		// An error occurred while connecting weights
		MessageText = NStr("en = 'An error occurred while enabling electronic scales.
		                   |Additional description: %AdditionalDetails%'; 
		                   |ru = 'При подключении электронных весов произошла ошибка.
		                   |Дополнительное описание: %AdditionalDetails%';
		                   |pl = 'Wystąpił błąd podczas włączania wag elektronicznych.
		                   |Dodatkowy opis: |%AdditionalDetails%';
		                   |es_ES = 'Ha ocurrido un error al activar las escalas electrónicas.
		                   |Descripción adicional: %AdditionalDetails%';
		                   |es_CO = 'Ha ocurrido un error al activar las escalas electrónicas.
		                   |Descripción adicional: %AdditionalDetails%';
		                   |tr = 'Elektronik tartı etkinleştirilirken hata oluştu.
		                   |Ek açıklama: %AdditionalDetails%';
		                   |it = 'Un errore si è registrato durante l''abilitazione di bilance elettroniche.
		                   |Descrizione aggiuntiva: |%AdditionalDetails%';
		                   |de = 'Beim Aktivieren der elektronischen Waage ist ein Fehler aufgetreten.
		                   |Zusätzliche Beschreibung: %AdditionalDetails%'");
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
		CommonClientServer.MessageToUser(ErrorDescription);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsSTSD

// Start exporting data in the data collection terminal.
// UUID - form identifiers.
// AlertOnDataExport - alert on data export end.
//
Procedure StartDataExportVTSD(AlertOnDataExport, UUID, ProductsExportTable) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnDataExport);
	Context.Insert("UUID" , UUID);
	Context.Insert("ProductsExportTable"  , ProductsExportTable);
	
	NotifyDescription = New NotifyDescription("StartDataExportToDCTEnd", ThisObject, Context);
	OfferSelectDevice(NotifyDescription, "DataCollectionTerminal",
		NStr("en = 'Select data collection terminal'; ru = 'Выберите терминал сбора данных';pl = 'Wybierz terminal zbioru danych';es_ES = 'Seleccionar el terminal de recopilación de datos';es_CO = 'Seleccionar el terminal de recopilación de datos';tr = 'Veri toplama terminalini seç';it = 'Selezionare la raccolta dati';de = 'Wählen Sie das Datenerfassungsterminal aus'"), NStr("en = 'Data collection terminal is not connected.'; ru = 'Терминал сбора данных не подключен.';pl = 'Terminal do zbierania danych nie jest podłączony.';es_ES = 'Terminal de recopilación de datos no está conectado.';es_CO = 'Terminal de recopilación de datos no está conectado.';tr = 'Veri toplama terminali bağlı değil.';it = 'Il terminale di raccolta dati non è collegato.';de = 'Datensammelterminal ist nicht verbunden.'"));
	
EndProcedure

Procedure StartDataExportToDCTEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	// Enable DCT
	Result = ConnectEquipmentByID(Parameters.UUID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		InputParameters  = New Array();
		Output_Parameters = Undefined;
				
		// Convert structures array to values list array with the predefined and fixed fields order:
		// 0 - Barcode
		// 1 - Products
		// 2 - MeasurementUnit
		// 3 - ProductsCharacteristic
		// 4 - ProductsSeries
		// 5 - Quality
		// 6 - Price
		// 7 - Count
		DCTArray = New Array;
		For Each curRow In Parameters.ProductsExportTable Do
			If curRow.Property("Products") Then
				ProductsDescription = String(curRow.Products);
			ElsIf curRow.Property("Description") Then
				ProductsDescription = curRow.Description;
			Else
				ProductsDescription = "";
			EndIf;
			DCTArrayRow = New ValueList; // Not an array for saving compatibility with maintenance processors.
			DCTArrayRow.Add(?(curRow.Property("Barcode")                   , curRow.Barcode, ""));
			DCTArrayRow.Add(ProductsDescription);
			DCTArrayRow.Add(?(curRow.Property("MeasurementUnit")           , curRow.MeasurementUnit, ""));
			DCTArrayRow.Add(?(curRow.Property("ProductsCharacteristic") , curRow.ProductsCharacteristic, ""));
			DCTArrayRow.Add(?(curRow.Property("ProductsSeries")          , curRow.ProductsSeries, ""));
			DCTArrayRow.Add(?(curRow.Property("Quality")                   , curRow.Quality, ""));
			DCTArrayRow.Add(?(curRow.Property("Price")                       , curRow.Price, 0));
			DCTArrayRow.Add(?(curRow.Property("Count")                 , curRow.Count, 0));
			DCTArray.Add(DCTArrayRow);
		EndDo;
				
		InputParameters.Add("Items");
		InputParameters.Add(DCTArray);
				
		Result = RunCommand(DeviceIdentifier, "ImportDirectory", InputParameters, Output_Parameters);
		If Not Result Then
			MessageText = NStr("en = 'An error occurred while exporting data to the data collection terminal.
			                   |%ErrorDescription%
			                   |Data is not exported to the data collection terminal.'; 
			                   |ru = 'При выгрузке данных в терминал сбора данных произошла ошибка.
			                   |%ErrorDescription%
			                   |Данные в терминал сбора данных не выгружены.';
			                   |pl = 'Wystąpił błąd podczas eksportowania danych do terminala zbierania danych.
			                   |%ErrorDescription%
			                   |Dane te nie są eksportowane do terminala zbierania danych.';
			                   |es_ES = 'Ha ocurrido un error al exportar los datos al terminal de recopilación de datos.
			                   |%ErrorDescription% 
			                   |Datos no se han exportado al terminal de recopilación de datos.';
			                   |es_CO = 'Ha ocurrido un error al exportar los datos al terminal de recopilación de datos.
			                   |%ErrorDescription% 
			                   |Datos no se han exportado al terminal de recopilación de datos.';
			                   |tr = 'Veri toplama terminaline veri verilirken bir hata oluştu. 
			                   |%ErrorDescription%
			                   |Veri, veri toplama terminaline aktarılmaz.';
			                   |it = 'Un errore si è registrato durante l''esportazione dei dati al terminal di raccolta dati.
			                   |%ErrorDescription%
			                   |I dati non sono ancora stati esportati al terminal di raccolta dati.';
			                   |de = 'Beim Exportieren von Daten in das Datenerfassungsterminal ist ein Fehler aufgetreten.
			                   |%ErrorDescription%
			                   |Daten werden nicht zum Datenerfassungsterminal exportiert.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			EndIf;
		EndIf;
		
		DisableEquipmentById(Parameters.UUID, DeviceIdentifier);
			
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.
		                   |%ErrorDescription%
		                   |Data is not exported to the data collection terminal.'; 
		                   |ru = 'При подключении устройства произошла ошибка.
		                   |%ErrorDescription%
		                   |Данные в терминал сбора данных не выгружены.';
		                   |pl = 'Wystąpił błąd podczas podłączania urządzenia.
		                   |%ErrorDescription%
		                   |Dane nie zostały wyeksportowane do terminala zbierania danych.';
		                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos no se han exportado al terminal de recopilación de datos.';
		                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos no se han exportado al terminal de recopilación de datos.';
		                   |tr = 'Cihaz bağlanırken hata oluştu.
		                   |%ErrorDescription%
		                   |Veriler, veri toplama terminaline aktarılamadı.';
		                   |it = 'Si è registrato un errore durante la connessione del dispositivo.
		                   |%ErrorDescription%
		                   |I dati non sono stati esportati nel terminale collettore di dati.';
		                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
		                   |%ErrorDescription%
		                   |n Daten werden nicht zum Datenerfassungsterminal exportiert.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
		
EndProcedure

// Start importing data from data collection terminal.
// UUID - form identifiers.
// AlertOnImportData - alert on data export end.
// CollapseData - minimize data on import (group by barcode and quantity summary).
//
Procedure StartImportDataFromDCT(AlertOnImportData, UUID, CollapseData = True) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnImportData);
	Context.Insert("UUID" , UUID);
	Context.Insert("CollapseData"       , CollapseData);
	
	NotifyDescription = New NotifyDescription("StartImportDataFromDCTEnd", ThisObject, Context);
	OfferSelectDevice(NotifyDescription, "DataCollectionTerminal",
		NStr("en = 'Select data collection terminal'; ru = 'Выберите терминал сбора данных';pl = 'Wybierz terminal zbioru danych';es_ES = 'Seleccionar el terminal de recopilación de datos';es_CO = 'Seleccionar el terminal de recopilación de datos';tr = 'Veri toplama terminalini seç';it = 'Selezionare la raccolta dati';de = 'Wählen Sie das Datenerfassungsterminal aus'"), NStr("en = 'Data collection terminal is not connected.'; ru = 'Терминал сбора данных не подключен.';pl = 'Terminal do zbierania danych nie jest podłączony.';es_ES = 'Terminal de recopilación de datos no está conectado.';es_CO = 'Terminal de recopilación de datos no está conectado.';tr = 'Veri toplama terminali bağlı değil.';it = 'Il terminale di raccolta dati non è collegato.';de = 'Datensammelterminal ist nicht verbunden.'"));
		
EndProcedure

Procedure StartImportDataFromDCTEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	// Enable DCT
	Result = ConnectEquipmentByID(Parameters.UUID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		Result = RunCommand(DeviceIdentifier, "ExportDocument", InputParameters, Output_Parameters);
		
		If Result Then
			
			TableImportFromDCT = New Array();       
			DataTable = New Map();
			
			For IndexOf = 0 To Output_Parameters[0].Count()/2 - 1 Do
				Barcode    = Output_Parameters[0][IndexOf * 2 + 0];
				Quantity = Number(?(Output_Parameters[0][IndexOf * 2 + 1] <> Undefined, Output_Parameters[0][IndexOf * 2 + 1], 0));
				If Parameters.CollapseData Then
					Data = DataTable.Get(Barcode);
					If Data = Undefined Then
						DataTable.Insert(Barcode, Quantity)
					Else
						DataTable.Insert(Barcode, Data + Quantity)
					EndIf;
				Else
					TableImportFromDCT.Add(New Structure("Barcode, Quantity", Barcode, Quantity));
				EndIf;
			EndDo;
					
			If Parameters.CollapseData Then
				For Each Data  In DataTable Do
					TableImportFromDCT.Add(New Structure("Barcode, Quantity", Data.Key, Data.Value));
				EndDo
			EndIf;
			
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, TableImportFromDCT);
			EndIf;
			
		Else
			MessageText = NStr("en = 'An error occurred while exporting data from the data collection terminal.
			                   |%ErrorDescription%
			                   |Data from the data collection terminal is not imported.'; 
			                   |ru = 'При загрузке данных из терминала сбора данных произошла ошибка.
			                   |%ErrorDescription%
			                   |Данные из терминала сбора данных не загружены.';
			                   |pl = 'Wystąpił błąd podczas eksportowania danych z terminala do zbierania danych.
			                   |%ErrorDescription%
			                   |Dane z terminala zbierania danych nie są importowane.';
			                   |es_ES = 'Ha ocurrido un error al exportar los datos desde el terminal de recopilación de datos.
			                   |%ErrorDescription%
			                   |Datos desde terminal de recopilación de datos no se han importado.';
			                   |es_CO = 'Ha ocurrido un error al exportar los datos desde el terminal de recopilación de datos.
			                   |%ErrorDescription%
			                   |Datos desde terminal de recopilación de datos no se han importado.';
			                   |tr = 'Veri toplama terminaline veri verilirken bir hata oluştu. 
			                   |%ErrorDescription%
			                   |Veri, veri toplama terminaline aktarılmaz.';
			                   |it = 'Si è verificato un errore durante l''esportazione dei dati dal terminale di raccolta dei dati. 
			                   |%ErrorDescription%
			                   |I dati dal terminale di raccolta dei dati non sono importati.';
			                   |de = 'Beim Exportieren von Daten vom Datenerfassungsterminal ist ein Fehler aufgetreten.
			                   |%ErrorDescription%
			                   |Daten vom Datenerfassungsterminal werden nicht importiert.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
		DisableEquipmentById(Parameters.UUID, DeviceIdentifier);
		
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.
		                   |%ErrorDescription%
		                   |Data from the data collection terminal is not imported.'; 
		                   |ru = 'При подключении устройства произошла ошибка.
		                   |%ErrorDescription%
		                   |Данные из терминала сбора данных не загружены.';
		                   |pl = 'Wystąpił błąd podczas podłączania urządzenia.
		                   |%ErrorDescription%
		                   |Dane z terminala zbierania danych nie są importowane.';
		                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos desde el terminal de recopilación de datos no se han importado.';
		                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos desde el terminal de recopilación de datos no se han importado.';
		                   |tr = 'Cihaz bağlanırken hata oluştu.
		                   |%ErrorDescription%
		                   |Veri toplama terminalindeki veriler içe aktarılamadı.';
		                   |it = 'Si è verificato un errore alla connessione del dispositivo.
		                   |%ErrorDescription%
		                   |I dati dal terminale di collezione dati non sono stati importati.';
		                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
		                   |%ErrorDescription%
		                   |Daten vom Datenerfassungsterminal werden nicht importiert.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Start clearing data in the data collection terminal.
// UUID - form identifiers.
// AlertWhenClearingData - alert on data clearing end.
//
Procedure StartClearingDataVTSD(AlertWhenClearingData, UUID) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertWhenClearingData);
	Context.Insert("UUID" , UUID);
	
	NotifyDescription = New NotifyDescription("StartClearingDataToDCTEnd", ThisObject, Context);
	OfferSelectDevice(NotifyDescription, "DataCollectionTerminal",
		NStr("en = 'Select data collection terminal'; ru = 'Выберите терминал сбора данных';pl = 'Wybierz terminal zbioru danych';es_ES = 'Seleccionar el terminal de recopilación de datos';es_CO = 'Seleccionar el terminal de recopilación de datos';tr = 'Veri toplama terminalini seç';it = 'Selezionare la raccolta dati';de = 'Wählen Sie das Datenerfassungsterminal aus'"), NStr("en = 'Data collection terminal is not connected.'; ru = 'Терминал сбора данных не подключен.';pl = 'Terminal do zbierania danych nie jest podłączony.';es_ES = 'Terminal de recopilación de datos no está conectado.';es_CO = 'Terminal de recopilación de datos no está conectado.';tr = 'Veri toplama terminali bağlı değil.';it = 'Il terminale di raccolta dati non è collegato.';de = 'Datensammelterminal ist nicht verbunden.'"));
		
EndProcedure

Procedure StartClearingDataToDCTEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	// Enable DCT
	Result = ConnectEquipmentByID(Parameters.UUID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		Result = RunCommand(DeviceIdentifier, "ClearTable", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en = 'An error occurred while clearing data in the data collection terminal.
			                   |%ErrorDescription%'; 
			                   |ru = 'При очистке данных в терминале сбора данных произошла ошибка.
			                   |%ErrorDescription%';
			                   |pl = 'Wystąpił błąd podczas usuwania danych w terminala zbierania danych.
			                   |%ErrorDescription%';
			                   |es_ES = 'Ha ocurrido un error al borrar los datos en el terminal de recopilación de datos.
			                   |%ErrorDescription%';
			                   |es_CO = 'Ha ocurrido un error al borrar los datos en el terminal de recopilación de datos.
			                   |%ErrorDescription%';
			                   |tr = 'Veri toplama terminalindeki verileri temizlenirken bir hata oluştu. 
			                   |%ErrorDescription%';
			                   |it = 'Si è verificato un errore durante la cancellazione dei dati nel terminale di raccolta dei dati. 
			                   |%ErrorDescription%';
			                   |de = 'Beim Löschen von Daten im Datenerfassungsterminal ist ein Fehler aufgetreten.
			                   |%ErrorDescription%'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			EndIf;
		EndIf;
		
		DisableEquipmentById(Parameters.UUID, DeviceIdentifier);
		
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.
		                   |%ErrorDescription%
		                   |Data is not exported to the data collection terminal.'; 
		                   |ru = 'При подключении устройства произошла ошибка.
		                   |%ErrorDescription%
		                   |Данные в терминал сбора данных не выгружены.';
		                   |pl = 'Wystąpił błąd podczas podłączania urządzenia.
		                   |%ErrorDescription%
		                   |Dane nie zostały wyeksportowane do terminala zbierania danych.';
		                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos no se han exportado al terminal de recopilación de datos.';
		                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos no se han exportado al terminal de recopilación de datos.';
		                   |tr = 'Cihaz bağlanırken hata oluştu.
		                   |%ErrorDescription%
		                   |Veriler, veri toplama terminaline aktarılamadı.';
		                   |it = 'Si è registrato un errore durante la connessione del dispositivo.
		                   |%ErrorDescription%
		                   |I dati non sono stati esportati nel terminale collettore di dati.';
		                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
		                   |%ErrorDescription%
		                   |n Daten werden nicht zum Datenerfassungsterminal exportiert.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithPOSProceduresAndFunctions

// Start enabling POS terminal. 
// If POS terminal does not support tickets printing on terminal, fiscal register is
// enabled for printing.
//
// Incoming parameters: 
//   UUID - form identifiers.
//   AlertOnEnd - alert on end enabling POS terminal.
//   POSTerminal - POS terminal will be selected if it is not specified.
// Outgoing parameters: - 
//   Structure with the following attributes.
//     EnabledDeviceIdentifierET - Identifier of enabled POS terminal.
//     FREnableDeviceID - Identifier of the enabled fiscal register.
//     ReceiptsPrintOnTerminal - supports tickets printing on the
//                                  terminal if True FRConnectedDeviceIdentifier = Undefined.
// After you use it, it is required to disable enabled devices using DisablePOSTerminal method.
//
Procedure StartEnablePOSTerminal(AlertOnEnd, UUID, POSTerminal = Undefined) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnEnd);
	Context.Insert("UUID" , UUID);
	
	If ValueIsFilled(POSTerminal) Then
		EnablePOSTerminalEnd(POSTerminal, Context);
	Else
		NotifyDescription = New NotifyDescription("EnablePOSTerminalEnd", ThisObject, Context);
		OfferSelectDevice(NotifyDescription, "POSTerminal",
			NStr("en = 'Select a POS terminal'; ru = 'Выберите эквайринговый терминал';pl = 'Wybierz terminal POS';es_ES = 'Seleccionar un terminal TPV';es_CO = 'Seleccionar un terminal TPV';tr = 'Bir POS terminali seçin';it = 'Selezionare il terminale POS';de = 'Wählen Sie ein POS-Terminal aus'"), NStr("en = 'POS terminal is not connected.'; ru = 'Эквайринговый терминал не подключен.';pl = 'Terminal POS nie jest podłączony.';es_ES = 'Terminal TPV no está conectado.';es_CO = 'Terminal TPV no está conectado.';tr = 'POS terminali bağlı değil.';it = 'Il terminale POS non è connesso.';de = 'POS-Terminal ist nicht verbunden.'"));
	EndIf;
	
EndProcedure

Procedure EnablePOSTerminalEnd(DeviceIdentifierET, Parameters) Export
	
	ErrorDescription = "";
	
	ResultET = ConnectEquipmentByID(Parameters.UUID, DeviceIdentifierET, ErrorDescription);
	
	If Not ResultET Then
		MessageText = NStr("en = 'When POS terminal connection there
		                   |was error: ""%ErrorDescription%"".
		                   |The operation was not performed.'; 
		                   |ru = 'При подключении эквайрингового
		                   |терминала произошла ошибка: ""%ErrorDescription%"".
		                   |Операция не была проведена.';
		                   |pl = 'W czasie połączenia wystąpił 
		                   |błąd podłączenia terminala POS: ""%ErrorDescription%""
		                   |Operacja nie została wykonana.';
		                   |es_ES = 'Al conectar el terminal TPV se ha producido
		                   |el error: ""%ErrorDescription%"".
		                   |La operación no se ha realizado.';
		                   |es_CO = 'Al conectar el terminal TPV se ha producido
		                   |el error: ""%ErrorDescription%"".
		                   |La operación no se ha realizado.';
		                   |tr = 'POS terminali bağlantısında
		                   |hata oluştu: ""%ErrorDescription%"".
		                   |İşlem gerçekleştirilemedi.';
		                   |it = 'Alla connessione del terminale POS,
		                   |si è verificato un errore: ""%ErrorDescription%"".
		                   |L''operazione non è stata eseguita.';
		                   |de = 'Bei der POS-Terminal-Verbindung ist
		                   |ein Fehler aufgetreten: ""%ErrorDescription%"".
		                   |Die Operation wurde nicht ausgeführt.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	Else
		
		InputParameters = New Array();
		Output_Parameters = Undefined;
		
		ResultET = RunCommand(DeviceIdentifierET, "PrintSlipOnTerminal", InputParameters, Output_Parameters);
		
		If Output_Parameters.Count() > 0 AND Output_Parameters[0] Then
			If Parameters.NextAlert <> Undefined Then
				CompletionParameters = New Structure;
				CompletionParameters.Insert("UUID"                , Parameters.UUID);
				CompletionParameters.Insert("EnabledDeviceIdentifierET" , DeviceIdentifierET);
				CompletionParameters.Insert("ReceiptsPrintOnTerminal"             , True);
 				Pause(1);
				ExecuteNotifyProcessing(Parameters.NextAlert, CompletionParameters);
			EndIf;
		Else
			Parameters.Insert("EnabledDeviceIdentifierET" , DeviceIdentifierET);
			Parameters.Insert("ReceiptsPrintOnTerminal"             , False);
			NotifyDescription = New NotifyDescription("EnableFiscalRegistrarEnd", ThisObject, Parameters);
			OfferSelectDevice(NotifyDescription, "FiscalRegister",
					NStr("en = 'Select a fiscal data recorder to print POS receipts.'; ru = 'Выберите фискальный регистратор для печати эквайринговых чеков';pl = 'Wybierz rejestrator fiskalny, w celu wydruku pokwitowania z terminala POS.';es_ES = 'Seleccionar un registrador de datos fiscal para imprimir los recibos del TPV.';es_CO = 'Seleccionar un registrador de datos fiscal para imprimir los recibos del TPV.';tr = 'POS fişlerini yazdırmak için mali kaydediciyi seçin.';it = 'Selezionare un registrare fiscale per la stampa delle ricevute POS';de = 'Wählen Sie einen Fiskaldatenschreiber, um Kassenbons zu drucken.'"), NStr("en = 'Fiscal data recorder for printing acquiring receipts is not connected.'; ru = 'Фискальный регистратор для печати эквайринговых чеков не подключен.';pl = 'Rejestrator fiskalny do drukowania potwierdzeń odbioru nie jest podłączony.';es_ES = 'Registrador de datos fiscal para imprimir los recibos de adquisición no está conectado.';es_CO = 'Registrador de datos fiscal para imprimir los recibos de adquisición no está conectado.';tr = 'Alınan fişlerin yazdırılması için mali veri kaydedici bağlı değil.';it = 'Il registrare fiscale per la stampa di ricevute non è connesso.';de = 'Fiskaldatenschreiber zum Drucken von Kassenbons ist nicht verbunden.'"));
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure EnableFiscalRegistrarEnd(DeviceIdentifierFR, Parameters) Export
	
	ErrorDescription = "";
	
	ResultFR = ConnectEquipmentByID(Parameters.UUID, DeviceIdentifierFR, ErrorDescription);
	
	If Not ResultFR Then
		
		// ET device disconnect
		If Not Parameters.EnabledDeviceIdentifierET = Undefined Then
			DisableEquipmentById(Parameters.UUID, Parameters.EnabledDeviceIdentifierET);
		EndIf;
			
		MessageText = NStr("en = 'The fiscal printer connection error:
                            |""%ErrorDescription%"".
                            |The operation cannot be performed.'; 
                            |ru = 'Ошибка подключения фискального принтера:
                            |""%ErrorDescription%"".
                            |Операция не может быть выполнена.';
                            |pl = 'Błąd podłączenia drukarki fiskalnej:
                            |""%ErrorDescription%"".
                            |Operacja nie może być wykonana.';
                            |es_ES = 'Error de conexión de la impresora fiscal:
                            |""%ErrorDescription%"".
                            |No se puede realizar la operación.';
                            |es_CO = 'Error de conexión de la impresora fiscal:
                            |""%ErrorDescription%"".
                            |No se puede realizar la operación.';
                            |tr = 'Mali yazıcı bağlantı hatası:
                            |""%ErrorDescription%"".
                            |İşlem tamamlanamıyor.';
                            |it = 'Errore di connessione della stampante fiscale:
                            |%ErrorDescription%.
                            |L''operazione non può essere eseguita.';
                            |de = 'Der Verbindungsfehler des Steuerdruckers:
                            |""%ErrorDescription%"".
                            |Die Operation kann nicht ausgeführt werden.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
		
	Else
		If Parameters.NextAlert <> Undefined Then
			CompletionParameters = New Structure;
			CompletionParameters.Insert("UUID"                , Parameters.UUID);
			CompletionParameters.Insert("EnabledDeviceIdentifierET" , Parameters.EnabledDeviceIdentifierET);
			CompletionParameters.Insert("ReceiptsPrintOnTerminal"             , Parameters.ReceiptsPrintOnTerminal);
			CompletionParameters.Insert("FREnableDeviceID" , DeviceIdentifierFR);
			ExecuteNotifyProcessing(Parameters.NextAlert, CompletionParameters);
		EndIf;
	EndIf;
	
EndProcedure

// Disable the enabled POS terminal. 
// If POS terminal does not support tickets printing on terminal, fiscal register
// is enabled for printing.
// This procedure also disconnects
// it/ Incoming parameters:  
//   Parameters  - Structure with the following attributes.
//     EnabledDeviceIdentifierET - Identifier of enabled POS terminal.
//     FREnableDeviceID - Identifier of the enabled fiscal register.
//     ReceiptsPrintOnTerminal - supports tickets printing on the
//                                  terminal if True FRConnectedDeviceIdentifier = Undefined.
//  UUID - form identifiers.
//
Procedure DisablePOSTerminal(UUID, Parameters) Export
	
	If Not Parameters.ReceiptsPrintOnTerminal AND Not Parameters.FREnableDeviceID = Undefined Then
		DisableEquipmentById(UUID, Parameters.FREnableDeviceID);
	EndIf;
	
	If Not Parameters.EnabledDeviceIdentifierET = Undefined Then
		DisableEquipmentById(UUID, Parameters.EnabledDeviceIdentifierET);
	EndIf;
	 
EndProcedure

Procedure ExecuteTotalsRevisionPOSTerminalEnd(Result, Parameters) Export
	
	If Not TypeOf(Result) = Type("Structure") Then
		MessageText = NStr("en = 'An error occurred while executing the operation.'; ru = 'При выполнении операции произошла ошибка.';pl = 'Wystąpił błąd podczas wykonywania operacji.';es_ES = 'Ha ocurrido un error al ejecutar la operación.';es_CO = 'Ha ocurrido un error al ejecutar la operación.';tr = 'İşlem yürütülürken hata oluştu.';it = 'Si è verificato un errore durante l''esecuzione dell''operazione';de = 'Während der Ausführung der Operation ist ein Fehler aufgetreten.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	UUID = Result.UUID;
	InputParameters  = Undefined;
	Output_Parameters = Undefined;
	
	// Executing the operation on POS terminal
	ResultET = RunCommand(Result.EnabledDeviceIdentifierET, "Settlement", InputParameters, Output_Parameters);
	
	If Not ResultET Then
		MessageText = NStr("en = 'When operation execution there
		                   |was error: ""%ErrorDescription%"".
		                   |Totals reconciliation is not executed.'; 
		                   |ru = 'При выполнении операции возникла ошибка:
		                   |""%ErrorDescription%"".
		                   |Отмена по карте не была произведена.';
		                   |pl = 'Podczas wykonywania operacji 
		                   |wystąpił błąd: ""%ErrorDescription%"".
		                   |Weryfikacja wyników nie została wykonana.';
		                   |es_ES = 'Al ejecutar la operación se ha producido
		                   |el error: ""%ErrorDescription%"".
		                   |Reconciliación de totales no se ha ejecutado.';
		                   |es_CO = 'Al ejecutar la operación se ha producido
		                   |el error: ""%ErrorDescription%"".
		                   |Reconciliación de totales no se ha ejecutado.';
		                   |tr = 'İşlemin yürütülmesi sırasında 
		                   |hata: ""%ErrorDescription%"". 
		                   |Toplamlar mutabakatı gerçekleştirilmedi.';
		                   |it = 'Durante l''esecuzione della operazione si
		                   |è registrato un errore: ""%ErrorDescription%"".
		                   |La riconciliazione totali non è stata eseguita.';
		                   |de = 'Bei der Ausführung der Operation ist
		                   |ein Fehler aufgetreten: ""%ErrorDescription%"".
		                   |nDie Summenabstimmung wird nicht ausgeführt.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
		CommonClientServer.MessageToUser(MessageText);
	Else
		
		SlipReceiptText = Output_Parameters[0][1];
		If Not IsBlankString(SlipReceiptText) Then
			glPeripherals.Insert("LastSlipReceipt", SlipReceiptText);
		EndIf;
	
		If Not Result.ReceiptsPrintOnTerminal AND Not Result.FREnableDeviceID = Undefined Then
			If Not IsBlankString(SlipReceiptText) Then
				
				InputParameters = New Array();
				InputParameters.Add(SlipReceiptText);
				Output_Parameters = Undefined;
				ResultFR = RunCommand(Result.FREnableDeviceID, "PrintText", InputParameters, Output_Parameters);
				
				If Not ResultFR Then
					MessageText = NStr("en = 'An error occurred while printing
					                   |a slip receipt: ""%ErrorDescription%"".'; 
					                   |ru = 'При печати слип чека
					                   |возникла ошибка: ""%ErrorDescription%"".';
					                   |pl = 'Wystąpił błąd podczas drukowania potwierdzenia
					                   |paragonu zakupu: ""%ErrorDescription%"".';
					                   |es_ES = 'Ha ocurrido un error al imprimir
					                   |un recibo de comprobante: ""%ErrorDescription%"".';
					                   |es_CO = 'Ha ocurrido un error al imprimir
					                   |un recibo de comprobante: ""%ErrorDescription%"".';
					                   |tr = 'Makbuz basılması sırasında
					                   |bir hata oluştu: ""%ErrorDescription%"".';
					                   |it = 'Si è verificato un errore durante la stampa
					                   |della ricevuta: ""%ErrorDescription%"".';
					                   |de = 'Beim Drucken
					                   |eines Empfangsbelegs ist ein Fehler aufgetreten: ""%ErrorDescription%"".'");
					MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
					CommonClientServer.MessageToUser(MessageText);
				EndIf;
			Else
				MessageText = NStr("en = 'Totals reconciliation successfully completed.'; ru = 'Операция сверки итогов успешно выполнена.';pl = 'Operacja weryfikacji wyników została pomyślnie zakończona.';es_ES = 'Reconciliación de totales se ha finalizado con éxito.';es_CO = 'Reconciliación de totales se ha finalizado con éxito.';tr = 'Toplam mutabakat başarıyla tamamlandı.';it = 'L''operazione di riconciliazione è stata completata con successo.';de = 'Die Gesamt- Summenabstimmung wurde erfolgreich abgeschlossen.'");
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
	EndIf;
	
	DisablePOSTerminal(UUID, Result);
	
EndProcedure

// Check totals on POS terminal.
// If POS terminal does not support tickets printing on terminal, fiscal register
// is enabled for printing.
//
// Incoming parameters: 
//   UUID - form identifiers.
//
Procedure RunTotalsOnPOSTerminalRevision(UUID) Export
	
	NotifyDescription = New NotifyDescription("ExecuteTotalsRevisionPOSTerminalEnd", ThisObject);
	StartEnablePOSTerminal(NotifyDescription, UUID);
	
EndProcedure

#EndRegion

#Region WorkWithScalesWithLabelsPrintingProceduresAndFunctions

Procedure StartDataExportToScalesWithLabelsPrinting(AlertOnDataExport, ClientID, DeviceIdentifier = Undefined, ProductsExportTable, PartialExport = False) Export
	
	If ProductsExportTable.Count() = 0 Then
		MessageText = NStr("en = 'There is no data to export.'; ru = 'Нет данных для выгрузки!';pl = 'Brak danych do eksportu.';es_ES = 'No hay datos para exportar.';es_CO = 'No hay datos para exportar.';tr = 'Dışa aktarılacak veri yok.';it = 'Non ci sono dati per l''esportazione!';de = 'Es gibt keine Daten zum Exportieren.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("NextAlert"    , AlertOnDataExport);
	Context.Insert("ClientID"   , ClientID);
	Context.Insert("ProductsExportTable" , ProductsExportTable);
	Context.Insert("PartialExport"      , PartialExport);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartDataExportToScalesWithLablesPrintingEnd", ThisObject, Context);
		OfferSelectDevice(NotifyDescription, "LabelsPrintingScales",
			NStr("en = 'Select label printing scales'; ru = 'Выберите весы с печатью этикеток';pl = 'Wybierz wagę do druku etykiet';es_ES = 'Seleccionar las escalas de impresión de etiquetas';es_CO = 'Seleccionar las escalas de impresión de etiquetas';tr = 'Etiket baskı terazileri seçin';it = 'Selezionare la bilancia stampa di etichette';de = 'Wählen Sie Etikettendruckwaagen aus'"), NStr("en = 'Label printing scales are not connected.'; ru = 'Весы с печатью этикеток не подключены.';pl = 'Wagi do drukowania etykiet nie są podłączone.';es_ES = 'Escalas de impresión de etiquetas no están conectadas.';es_CO = 'Escalas de impresión de etiquetas no están conectadas.';tr = 'Etiket baskısı terazileri bağlı değil.';it = 'Le bilance con stampa di etichette non sono collegate.';de = 'Etikettendruckwaagen sind nicht verbunden.'"));
	Else
		StartDataExportToScalesWithLablesPrintingEnd(DeviceIdentifier, Context);
	EndIf;
	
EndProcedure

Procedure StartDataExportToScalesWithLablesPrintingEnd(DeviceIdentifier, Parameters) Export
	
	Parameters.Insert("DeviceIdentifier", DeviceIdentifier);
#If WebClient Then
	NotifyDescription = New NotifyDescription("StartDataExportToScalesWithLabelsPrintingFileExtensionEnd", ThisObject, Parameters);
	CheckFileOperationsExtensionAvailability(NotifyDescription, False);
#Else
	// The extension is always enabled in thin and thick client.
	StartDataExportToScalesWithLabelsPrintingFileExtensionEnd(True, Parameters);
#EndIf
	
EndProcedure

Procedure StartDataExportToScalesWithLabelsPrintingFileExtensionEnd(Attached, Parameters) Export
	
	If Not Attached Then
		MessageText = NStr("en = 'The operation is not available without extension for 1C:Enterprise web client installed.'; ru = 'Данная операция не доступна без установленного расширения для веб-клиента ""1С:Предприятие"".';pl = 'Operacja nie jest dostępna bez zainstalowanego rozszerzenia dla klienta webowego 1C:Enterprise.';es_ES = 'La operación no está disponible sin la extensión para el cliente web de la 1C:Empresa instalada.';es_CO = 'La operación no está disponible sin la extensión para el cliente web de la 1C:Empresa instalada.';tr = 'İşlem, 1C:Enterprise web istemcisi uzantısı kurulmadan yapılamaz.';it = 'Questa operazione non è disponibile senza l''estensione Web Clien installata per 1C: Enterprise.';de = 'Die Operation ist ohne Erweiterung für 1C:Enterprise Web Client nicht verfügbar.'");
		CommonClientServer.MessageToUser(MessageText);
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, False);
		EndIf;
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = ConnectEquipmentByID(Parameters.ClientID, Parameters.DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		ProductsArray = New Array;
		For Each TSRow In Parameters.ProductsExportTable Do
			ArrayElement = New Structure("PLU, Code, Barcode, Description, DescriptionFull, Price", 0, 0, "", "" , 0);
			ArrayElement.PLU = TSRow.PLU;
			ArrayElement.Code = TSRow.Code;
			ArrayElement.Description = ?(TSRow.Property("Products"), String(TSRow.Products), ?(TSRow.Property("Description"), String(TSRow.Description), ""));
			ArrayElement.DescriptionFull = ?(TSRow.Property("DescriptionFull"), String(TSRow.DescriptionFull), "");
			ArrayElement.DescriptionFull = ?(IsBlankString(ArrayElement.DescriptionFull), ArrayElement.Description, ArrayElement.DescriptionFull); 
			ArrayElement.Price = TSRow.Price;
			ProductsArray.Add(ArrayElement);
		EndDo;
		
		InputParameters  = New Array;
		InputParameters.Add(ProductsArray);
		InputParameters.Add(Parameters.PartialExport); // Partial export.
		Output_Parameters = Undefined;
			
		Result = RunCommand(Parameters.DeviceIdentifier, "ExportProducts", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en = 'An error occurred while exporting data to equipment.
			                   |%ErrorDescription%
			                   |Data is not exported.'; 
			                   |ru = 'При выгрузке данных в оборудование произошла ошибка.
			                   |%ErrorDescription%
			                   |Данные не выгружены.';
			                   |pl = 'Wystąpił błąd podczas eksportowania danych do sprzętu.
			                   |%ErrorDescription%
			                   |Dane nie były wyeksportowane.';
			                   |es_ES = 'Ha ocurrido un error al exportar los datos al equipamiento.
			                   |%ErrorDescription%
			                   |Datos no se han exportado.';
			                   |es_CO = 'Ha ocurrido un error al exportar los datos al equipamiento.
			                   |%ErrorDescription%
			                   |Datos no se han exportado.';
			                   |tr = 'Verileri ekipmana dışa aktarırken bir hata oluştu.
			                   |%ErrorDescription%
			                   | Veriler dışa aktarılmadı.';
			                   |it = 'Si è registrato un errore durante l''esportazione dati all''attrezzatura.
			                   |%ErrorDescription%
			                   |I dati non sono stati esportati.';
			                   |de = 'Beim Exportieren von Daten in Equipment ist ein Fehler aufgetreten.
			                   |%ErrorDescription%
			                   |Daten werden nicht exportiert.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			Else
				MessageText = NStr("en = 'Data downloaded successfully.'; ru = 'Данные выгружены успешно.';pl = 'Dane zostały pomyślnie pobrane.';es_ES = 'Datos se han descargado con éxito.';es_CO = 'Datos se han descargado con éxito.';tr = 'Veri başarıyla indirildi.';it = 'Dati scaricati con successo.';de = 'Daten wurden erfolgreich heruntergeladen.'");
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
		DisableEquipmentById(Parameters.ClientID, Parameters.DeviceIdentifier);
		
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.
		                   |%ErrorDescription%
		                   |Data is not exported.'; 
		                   |ru = 'При подключении устройства произошла ошибка.
		                   |%ErrorDescription%
		                   |Данные не выгружены.';
		                   |pl = 'Wystąpił błąd podczas podłączania urządzenia.
		                   |%ErrorDescription%
		                   |Dane nie zostały wyeksportowane.';
		                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos no se han exportado.';
		                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos no se han exportado.';
		                   |tr = 'Cihaz bağlanırken hata oluştu.
		                   |%ErrorDescription%
		                   | Veriler dışa aktarılmadı.';
		                   |it = 'Si è verificato un errore alla connessione del dispositivo.
		                   |%ErrorDescription%
		                   |I dati non sono stati esportati.';
		                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
		                   |%ErrorDescription%
		                   |Daten werden nicht exportiert.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

Procedure StartClearingProductsInScalesWithLabelsPrinting(AlertWhenClearingData, ClientID, DeviceIdentifier = Undefined) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"  , AlertWhenClearingData);
	Context.Insert("ClientID" , ClientID);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartClearingProductsInScalesWithLabelsPrintingEnd", ThisObject, Context);
		OfferSelectDevice(NotifyDescription, "LabelsPrintingScales",
			NStr("en = 'Select label printing scales'; ru = 'Выберите весы с печатью этикеток';pl = 'Wybierz wagę do druku etykiet';es_ES = 'Seleccionar las escalas de impresión de etiquetas';es_CO = 'Seleccionar las escalas de impresión de etiquetas';tr = 'Etiket baskı terazileri seçin';it = 'Selezionare la bilancia stampa di etichette';de = 'Wählen Sie Etikettendruckwaagen aus'"), NStr("en = 'Label printing scales are not connected.'; ru = 'Весы с печатью этикеток не подключены.';pl = 'Wagi do drukowania etykiet nie są podłączone.';es_ES = 'Escalas de impresión de etiquetas no están conectadas.';es_CO = 'Escalas de impresión de etiquetas no están conectadas.';tr = 'Etiket baskısı terazileri bağlı değil.';it = 'Le bilance con stampa di etichette non sono collegate.';de = 'Etikettendruckwaagen sind nicht verbunden.'"));
	Else
		StartClearingProductsInScalesWithLabelsPrintingEnd(DeviceIdentifier, Context);
	EndIf;
	
EndProcedure

Procedure StartClearingProductsInScalesWithLabelsPrintingEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	
	Result = ConnectEquipmentByID(Parameters.ClientID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		Result = RunCommand(DeviceIdentifier, "ClearBase", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en = 'An error occurred while clearing data to equipment.
			                   |%ErrorDescription%'; 
			                   |ru = 'При очистке данных в оборудование произошла ошибка.
			                   |%ErrorDescription%';
			                   |pl = 'Wystąpił błąd podczas usuwania danych z urządzenia.
			                   |%ErrorDescription%';
			                   |es_ES = 'Ha ocurrido un error al borrar los datos para el equipamiento.
			                   |%ErrorDescription%';
			                   |es_CO = 'Ha ocurrido un error al borrar los datos para el equipamiento.
			                   |%ErrorDescription%';
			                   |tr = 'Verileri ekipmana temizlenirken bir hata oluştu
			                   |%ErrorDescription%';
			                   |it = 'Si è registrato un errore durante l''annullamento dati all''attrezzatura.
			                   |%ErrorDescription%';
			                   |de = 'Beim Löschen von Daten zu Geräten ist ein Fehler aufgetreten.
			                   |%ErrorDescription%'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			
			CommonClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			Else
				MessageText = NStr("en = 'Data is successfully cleared.'; ru = 'Очистка данных успешно завершена.';pl = 'Dane zostały pomyślnie usunięte.';es_ES = 'Datos se han borrado con éxito.';es_CO = 'Datos se han borrado con éxito.';tr = 'Veri başarıyla temizlendi.';it = 'I dati sono stati cancellati con successo.';de = 'Daten werden erfolgreich gelöscht.'");
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
			
		DisableEquipmentById(Parameters.ClientID, DeviceIdentifier);
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.
		                   |%ErrorDescription%'; 
		                   |ru = 'При подключении устройства произошла ошибка.
		                   |%ErrorDescription%';
		                   |pl = 'Wystąpił błąd podczas podłączenia urządzenia.
		                   |%ErrorDescription%';
		                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%';
		                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%';
		                   |tr = 'Cihaz bağlanırken hata oluştu.
		                   |%ErrorDescription%';
		                   |it = 'Un errore si è registrato durante la connessione del dispositivo.
		                   |%ErrorDescription%';
		                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
		                   |%ErrorDescription%'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithEquipmentCRProceduresAndFunctionsOffline

// Clears products in CR Offline.
//
Procedure StartProductsCleaningInCROffline(AlertWhenClearingData, UUID, DeviceIdentifier = Undefined) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertWhenClearingData);
	Context.Insert("UUID" , UUID);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartCleaningProductsCROfflineEnd", ThisObject, Context);
		OfferSelectDevice(NotifyDescription, "CashRegistersOffline",
			NStr("en = 'Select offline CR'; ru = 'Выберите ККМ Offline';pl = 'Wybierz kasy fiskalne';es_ES = 'Seleccionar CR offline';es_CO = 'Seleccionar CR offline';tr = 'Çevrimdışı yazar kasa seçin';it = 'Selezionare registratore di cassa offline';de = 'Wählen Sie Offline-Kassen'"), NStr("en = 'Offline cash registers are not connected.'; ru = 'ККМ Offline не подключены.';pl = 'Kasy fiskalne offline nie są podłączone.';es_ES = 'Cajas registradoras offline no están conectadas.';es_CO = 'Cajas registradoras offline no están conectadas.';tr = 'Çevrimdışı yazar kasalar bağlı değil.';it = 'I registratori di cassa online non sono collegati';de = 'Offline-Kassen sind nicht verbunden.'"));
	Else
		StartCleaningProductsCROfflineEnd(DeviceIdentifier, Context);
	EndIf;
	
EndProcedure

Procedure StartCleaningProductsCROfflineEnd(DeviceIdentifier, Parameters) Export
	
	Parameters.Insert("DeviceIdentifier", DeviceIdentifier);
#If WebClient Then
	NotifyDescription = New NotifyDescription("StartCleaningProductsToCROfflineFileExtensionEnd", ThisObject, Parameters);
	CheckFileOperationsExtensionAvailability(NotifyDescription, False);
#Else
	// The extension is always enabled in thin and thick client.
	StartCleaningProductsToCROfflineFileExtensionEnd(True, Parameters);
#EndIf
	
EndProcedure

Procedure StartCleaningProductsToCROfflineFileExtensionEnd(Attached, Parameters) Export
	
	If Not Attached Then
		MessageText = NStr("en = 'The operation is not available without extension for 1C:Enterprise web client installed.'; ru = 'Данная операция не доступна без установленного расширения для веб-клиента ""1С:Предприятие"".';pl = 'Operacja nie jest dostępna bez zainstalowanego rozszerzenia dla klienta webowego 1C:Enterprise.';es_ES = 'La operación no está disponible sin la extensión para el cliente web de la 1C:Empresa instalada.';es_CO = 'La operación no está disponible sin la extensión para el cliente web de la 1C:Empresa instalada.';tr = 'İşlem, 1C:Enterprise web istemcisi uzantısı kurulmadan yapılamaz.';it = 'Questa operazione non è disponibile senza l''estensione Web Clien installata per 1C: Enterprise.';de = 'Die Operation ist ohne Erweiterung für 1C:Enterprise Web Client nicht verfügbar.'");
		CommonClientServer.MessageToUser(MessageText);
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, False);
		EndIf;
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = ConnectEquipmentByID(Parameters.UUID, Parameters.DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		Status(NStr("en = 'Clearing goods in offline cash register...'; ru = 'Выполняется очистка товаров в ККМ Offline...';pl = 'Rozliczanie towarów w kasie fiskalnej offline...';es_ES = 'Borrando las mercancías en la caja registradora offline...';es_CO = 'Borrando las mercancías en la caja registradora offline...';tr = 'Çevrimdışı yazar kasadaki mallar temizleniyor...';it = 'I prodotti vengono cancellati dal registratore di cassa Offline ...';de = 'Waren in Offline-Kasse löschen...'"));
		
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		Result = RunCommand(Parameters.DeviceIdentifier, "ClearBase", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en = 'An error occurred while clearing data to equipment.
			                   |%ErrorDescription%'; 
			                   |ru = 'При очистке данных в оборудование произошла ошибка.
			                   |%ErrorDescription%';
			                   |pl = 'Wystąpił błąd podczas usuwania danych z urządzenia.
			                   |%ErrorDescription%';
			                   |es_ES = 'Ha ocurrido un error al borrar los datos para el equipamiento.
			                   |%ErrorDescription%';
			                   |es_CO = 'Ha ocurrido un error al borrar los datos para el equipamiento.
			                   |%ErrorDescription%';
			                   |tr = 'Verileri ekipmana temizlenirken bir hata oluştu
			                   |%ErrorDescription%';
			                   |it = 'Si è registrato un errore durante l''annullamento dati all''attrezzatura.
			                   |%ErrorDescription%';
			                   |de = 'Beim Löschen von Daten zu Geräten ist ein Fehler aufgetreten.
			                   |%ErrorDescription%'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
		DisableEquipmentById(Parameters.UUID, Parameters.DeviceIdentifier);
		
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, Result);
		EndIf;
			
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.
		                   |%ErrorDescription%'; 
		                   |ru = 'При подключении устройства произошла ошибка.
		                   |%ErrorDescription%';
		                   |pl = 'Wystąpił błąd podczas podłączenia urządzenia.
		                   |%ErrorDescription%';
		                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%';
		                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%';
		                   |tr = 'Cihaz bağlanırken hata oluştu.
		                   |%ErrorDescription%';
		                   |it = 'Un errore si è registrato durante la connessione del dispositivo.
		                   |%ErrorDescription%';
		                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
		                   |%ErrorDescription%'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Export table with data to CR Offline.
// 
Procedure StartDataExportToCROffline(AlertOnDataExport, UUID, DeviceIdentifier = Undefined,
	ProductsExportTable, PartialExport = False) Export
	
	If ProductsExportTable.Count() = 0 Then
		MessageText = NStr("en = 'There is no data to export.'; ru = 'Нет данных для выгрузки!';pl = 'Brak danych do eksportu.';es_ES = 'No hay datos para exportar.';es_CO = 'No hay datos para exportar.';tr = 'Dışa aktarılacak veri yok.';it = 'Non ci sono dati per l''esportazione!';de = 'Es gibt keine Daten zum Exportieren.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnDataExport);
	Context.Insert("UUID" , UUID);
	Context.Insert("ProductsExportTable"  , ProductsExportTable);
	Context.Insert("PartialExport"       , PartialExport);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartDataExportToCROfflineEnd", ThisObject, Context);
		OfferSelectDevice(NotifyDescription, "CashRegistersOffline",
			NStr("en = 'Select offline CR'; ru = 'Выберите ККМ Offline';pl = 'Wybierz kasy fiskalne';es_ES = 'Seleccionar CR offline';es_CO = 'Seleccionar CR offline';tr = 'Çevrimdışı yazar kasa seçin';it = 'Selezionare registratore di cassa offline';de = 'Wählen Sie Offline-Kassen'"), NStr("en = 'Offline cash registers are not connected.'; ru = 'ККМ Offline не подключены.';pl = 'Kasy fiskalne offline nie są podłączone.';es_ES = 'Cajas registradoras offline no están conectadas.';es_CO = 'Cajas registradoras offline no están conectadas.';tr = 'Çevrimdışı yazar kasalar bağlı değil.';it = 'I registratori di cassa online non sono collegati';de = 'Offline-Kassen sind nicht verbunden.'"));
	Else
		StartDataExportToCROfflineEnd(DeviceIdentifier, Context);
	EndIf;
	
EndProcedure

Procedure StartDataExportToCROfflineEnd(DeviceIdentifier, Parameters) Export
	
	Parameters.Insert("DeviceIdentifier", DeviceIdentifier);
#If WebClient Then
	NotifyDescription = New NotifyDescription("StartDataExportToCROfflineFileExtensionEnd", ThisObject, Parameters);
	CheckFileOperationsExtensionAvailability(NotifyDescription, False);
#Else
	// The extension is always enabled in thin and thick client.
	StartDataExportToCROfflineFileExtensionEnd(True, Parameters);
#EndIf
	
EndProcedure

Procedure StartDataExportToCROfflineFileExtensionEnd(Attached, Parameters) Export
	
	If Not Attached Then
		MessageText = NStr("en = 'The operation is not available without extension for 1C:Enterprise web client installed.'; ru = 'Данная операция не доступна без установленного расширения для веб-клиента ""1С:Предприятие"".';pl = 'Operacja nie jest dostępna bez zainstalowanego rozszerzenia dla klienta webowego 1C:Enterprise.';es_ES = 'La operación no está disponible sin la extensión para el cliente web de la 1C:Empresa instalada.';es_CO = 'La operación no está disponible sin la extensión para el cliente web de la 1C:Empresa instalada.';tr = 'İşlem, 1C:Enterprise web istemcisi uzantısı kurulmadan yapılamaz.';it = 'Questa operazione non è disponibile senza l''estensione Web Clien installata per 1C: Enterprise.';de = 'Die Operation ist ohne Erweiterung für 1C:Enterprise Web Client nicht verfügbar.'");
		CommonClientServer.MessageToUser(MessageText);
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, False);
		EndIf;
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = ConnectEquipmentByID(Parameters.UUID, Parameters.DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		Status(NStr("en = 'Goods are being exported to offline CR...'; ru = 'Выполняется выгрузка товаров в ККМ Offline...';pl = 'Towary są eksportowane do offline CR...';es_ES = 'Mercancías se están exportando para la caja registradora offline...';es_CO = 'Mercancías se están exportando para la caja registradora offline...';tr = 'Mallar çevrimdışı yazar kasaya aktarılıyor...';it = 'I prodotti vengono esportati in un registratore di cassa offline ...';de = 'Waren werden in Offline-Kassen exportiert...'")); 
		
		ProductsArray = New Array;
		For Each TSRow In Parameters.ProductsExportTable Do
			ArrayElement = New Structure("Code, SKU, Barcode, Description, DescriptionFull, MeasurementUnit, Price, Balance, WeightProduct");
			ArrayElement.Code                = TSRow.Code;
			ArrayElement.SKU            = ?(TSRow.Property("SKU"), TSRow.SKU, "");
			ArrayElement.Barcode           = TSRow.Barcode;
			ArrayElement.Description       = TSRow.Description;
			ArrayElement.DescriptionFull = TSRow.DescriptionFull;
			ArrayElement.MeasurementUnit   = TSRow.MeasurementUnit;
			ArrayElement.Price               = TSRow.Price;
			ArrayElement.Balance            = ?(TSRow.Property("Balance"), TSRow.Balance, 0);
			ArrayElement.WeightProduct       = ?(TSRow.Property("WeightProduct"), TSRow.WeightProduct, False);
			ProductsArray.Add(ArrayElement);
		EndDo;
		
		InputParameters  = New Array;
		InputParameters.Add(ProductsArray);
		InputParameters.Add(Parameters.PartialExport); // Partial export.
		Output_Parameters = Undefined;
			
		Result = RunCommand(Parameters.DeviceIdentifier, "ExportProducts", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en = 'An error occurred while exporting data to equipment.
			                   |%ErrorDescription%
			                   |Data is not exported.'; 
			                   |ru = 'При выгрузке данных в оборудование произошла ошибка.
			                   |%ErrorDescription%
			                   |Данные не выгружены.';
			                   |pl = 'Wystąpił błąd podczas eksportowania danych do sprzętu.
			                   |%ErrorDescription%
			                   |Dane nie były wyeksportowane.';
			                   |es_ES = 'Ha ocurrido un error al exportar los datos al equipamiento.
			                   |%ErrorDescription%
			                   |Datos no se han exportado.';
			                   |es_CO = 'Ha ocurrido un error al exportar los datos al equipamiento.
			                   |%ErrorDescription%
			                   |Datos no se han exportado.';
			                   |tr = 'Verileri ekipmana dışa aktarırken bir hata oluştu.
			                   |%ErrorDescription%
			                   | Veriler dışa aktarılmadı.';
			                   |it = 'Si è registrato un errore durante l''esportazione dati all''attrezzatura.
			                   |%ErrorDescription%
			                   |I dati non sono stati esportati.';
			                   |de = 'Beim Exportieren von Daten in Equipment ist ein Fehler aufgetreten.
			                   |%ErrorDescription%
			                   |Daten werden nicht exportiert.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			Else
				MessageText = NStr("en = 'Data downloaded successfully.'; ru = 'Данные выгружены успешно.';pl = 'Dane zostały pomyślnie pobrane.';es_ES = 'Datos se han descargado con éxito.';es_CO = 'Datos se han descargado con éxito.';tr = 'Veri başarıyla indirildi.';it = 'Dati scaricati con successo.';de = 'Daten wurden erfolgreich heruntergeladen.'");
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
		DisableEquipmentById(Parameters.UUID, Parameters.DeviceIdentifier);
		
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.
		                   |%ErrorDescription%
		                   |Data is not exported.'; 
		                   |ru = 'При подключении устройства произошла ошибка.
		                   |%ErrorDescription%
		                   |Данные не выгружены.';
		                   |pl = 'Wystąpił błąd podczas podłączania urządzenia.
		                   |%ErrorDescription%
		                   |Dane nie zostały wyeksportowane.';
		                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos no se han exportado.';
		                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%
		                   |Datos no se han exportado.';
		                   |tr = 'Cihaz bağlanırken hata oluştu.
		                   |%ErrorDescription%
		                   | Veriler dışa aktarılamadı.';
		                   |it = 'Si è verificato un errore alla connessione del dispositivo.
		                   |%ErrorDescription%
		                   |I dati non sono stati esportati.';
		                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
		                   |%ErrorDescription%
		                   |Daten werden nicht exportiert.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Start importing data from CR Offline.
// UUID - form identifiers.
// AlertOnImportData - alert on data export end.
//
Procedure StartImportRetailSalesReportFromCROffline(AlertOnImportData, UUID, DeviceIdentifier = Undefined) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnImportData);
	Context.Insert("UUID" , UUID);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartImportRetailSalesReportFromCROfflineEnd", ThisObject, Context);
		OfferSelectDevice(NotifyDescription, "CashRegistersOffline",
			NStr("en = 'Select offline CR'; ru = 'Выберите ККМ Offline';pl = 'Wybierz kasy fiskalne';es_ES = 'Seleccionar CR offline';es_CO = 'Seleccionar CR offline';tr = 'Çevrimdışı yazar kasa seçin';it = 'Selezionare registratore di cassa offline';de = 'Wählen Sie Offline-Kassen'"), NStr("en = 'Offline cash registers are not connected.'; ru = 'ККМ Offline не подключены.';pl = 'Kasy fiskalne offline nie są podłączone.';es_ES = 'Cajas registradoras offline no están conectadas.';es_CO = 'Cajas registradoras offline no están conectadas.';tr = 'Çevrimdışı yazar kasalar bağlı değil.';it = 'I registratori di cassa online non sono collegati';de = 'Offline-Kassen sind nicht verbunden.'"));
	Else
		StartImportRetailSalesReportFromCROfflineEnd(DeviceIdentifier, Context);
	EndIf;
		
EndProcedure

Procedure StartImportRetailSalesReportFromCROfflineEnd(DeviceIdentifier, Parameters) Export
	
	Parameters.Insert("DeviceIdentifier", DeviceIdentifier);
#If WebClient Then
	NotifyDescription = New NotifyDescription("StartImportRetailSalesReportFromCROfflineFileExtensionEnd", ThisObject, Parameters);
	CheckFileOperationsExtensionAvailability(NotifyDescription, False);
#Else
	// The extension is always enabled in thin and thick client.
	StartImportRetailSalesReportFromCROfflineFileExtensionEnd(True, Parameters);
#EndIf
	
EndProcedure

Procedure StartImportRetailSalesReportFromCROfflineFileExtensionEnd(Attached, Parameters) Export
	
	If Not Attached Then
		MessageText = NStr("en = 'The operation is not available without extension for 1C:Enterprise web client installed.'; ru = 'Данная операция не доступна без установленного расширения для веб-клиента ""1С:Предприятие"".';pl = 'Operacja nie jest dostępna bez zainstalowanego rozszerzenia dla klienta webowego 1C:Enterprise.';es_ES = 'La operación no está disponible sin la extensión para el cliente web de la 1C:Empresa instalada.';es_CO = 'La operación no está disponible sin la extensión para el cliente web de la 1C:Empresa instalada.';tr = 'İşlem, 1C:Enterprise web istemcisi uzantısı kurulmadan yapılamaz.';it = 'Questa operazione non è disponibile senza l''estensione Web Clien installata per 1C: Enterprise.';de = 'Die Operation ist ohne Erweiterung für 1C:Enterprise Web Client nicht verfügbar.'");
		CommonClientServer.MessageToUser(MessageText);
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, False);
		EndIf;
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = ConnectEquipmentByID(Parameters.UUID, Parameters.DeviceIdentifier, ErrorDescription);
	
	If Result Then
		Status(NStr("en = 'Importing goods from offline cash register...'; ru = 'Выполняется загрузка товаров из ККМ Offline...';pl = 'Import towarów z kasy fiskalnej offline...';es_ES = 'Importando las mercancías desde la caja registradora offline...';es_CO = 'Importando las mercancías desde la caja registradora offline...';tr = 'Çevrimdışı yazar kasadaki mallar içe aktarılıyor...';it = 'I prodotti sono importati dal registratore di cassa Offline ..';de = 'Waren von der Offline-Kasse importieren...'"));
		
		InputParameters  = New Array;
		Output_Parameters = Undefined;
		
		Result = RunCommand(Parameters.DeviceIdentifier, "ImportReport", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en = 'An error occurred while importing data from CR Offline.
			                   |%ErrorDescription%'; 
			                   |ru = 'При загрузка данных из ККМ Offline произошла ошибка.
			                   |%ErrorDescription%';
			                   |pl = 'Wystąpił błąd podczas importowania danych z CR Offline.
			                   |%ErrorDescription%';
			                   |es_ES = 'Ha ocurrido un error al importar los datos desde la CR Offline.
			                   |%ErrorDescription%';
			                   |es_CO = 'Ha ocurrido un error al importar los datos desde la CR Offline.
			                   |%ErrorDescription%';
			                   |tr = 'Çevrimdışı yazar kasadaki veriler içe aktarılırken hata oluştu.
			                   |%ErrorDescription%';
			                   |it = 'Si è verificato un errore durante l''importazione di dati da CR Offline.
			                   |%ErrorDescription%';
			                   |de = 'Beim Importieren von Daten aus Kassen Offline ist ein Fehler aufgetreten.
			                   |%ErrorDescription%'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		Else
			ProductsImportTable = Output_Parameters[0];
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, ProductsImportTable);
			EndIf;
		EndIf;
		
		DisableEquipmentById(Parameters.UUID, Parameters.DeviceIdentifier);
		
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.
		                   |%ErrorDescription%'; 
		                   |ru = 'При подключении устройства произошла ошибка.
		                   |%ErrorDescription%';
		                   |pl = 'Wystąpił błąd podczas podłączenia urządzenia.
		                   |%ErrorDescription%';
		                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%';
		                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%';
		                   |tr = 'Cihaz bağlanırken hata oluştu.
		                   |%ErrorDescription%';
		                   |it = 'Un errore si è registrato durante la connessione del dispositivo.
		                   |%ErrorDescription%';
		                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
		                   |%ErrorDescription%'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Start outputting check box on report import.
//
Procedure StartCheckBoxReportImportedCROffline(UUID, DeviceIdentifier) Export;
	
	ErrorDescription = "";
	
	Result = ConnectEquipmentByID(UUID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		RunCommand(DeviceIdentifier, "ReportImported", InputParameters, Output_Parameters);
	    DisableEquipmentById(UUID, DeviceIdentifier);
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.
		                   |%ErrorDescription%'; 
		                   |ru = 'При подключении устройства произошла ошибка.
		                   |%ErrorDescription%';
		                   |pl = 'Wystąpił błąd podczas podłączenia urządzenia.
		                   |%ErrorDescription%';
		                   |es_ES = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%';
		                   |es_CO = 'Ha ocurrido un error al conectar el dispositivo.
		                   |%ErrorDescription%';
		                   |tr = 'Cihaz bağlanırken hata oluştu.
		                   |%ErrorDescription%';
		                   |it = 'Un errore si è registrato durante la connessione del dispositivo.
		                   |%ErrorDescription%';
		                   |de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.
		                   |%ErrorDescription%'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithPrintDevicesProceduresAndFunctions

// Function receives the width of row in characters.
//  
Function GetPrintingDeviceRowWidth(DeviceIdentifier) Export
	
	InputParameters  = Undefined;
	Output_Parameters = Undefined;
	
	Result = RunCommand(DeviceIdentifier, "GetLineLength", InputParameters, Output_Parameters);    
	
	If Result Then
		Return Output_Parameters[0];
	Else
		Return Undefined;
	EndIf;
	
EndFunction

#EndRegion

#Region WorkWithInputDevicesProceduresAndFunctions

// Defines correspondence between card code and template.
// Input:
// TracksData - Array containing rows of lane code. 3 items totally.
// PatternData - a structure containing template data:
// - Suffix
// - Prefix
// - BlocksDelimiter
// - CodeLength
// Output:
// True - code corresponds to template.
// Message to user on things that do not correspond.
Function CodeCorrespondsToMCTemplate(TracksData, PatternData) Export
	
	OneTrackExist = False;
	CheckPassed = True;
	
	For Iterator = 1 To 3 Do
		If PatternData["TrackAvailability"+String(Iterator)] Then
			OneTrackExist = True;
			curRow = TracksData[Iterator - 1];
			If Right(curRow, StrLen(PatternData["Suffix" + String(Iterator)])) <> PatternData["Suffix" + String(Iterator)] Then
				CommonClientServer.MessageToUser(NStr("en = 'Track'; ru = 'Дорожка';pl = 'Ścieżka';es_ES = 'Seguimiento';es_CO = 'Seguimiento';tr = 'Yol';it = 'Traccia';de = 'Spur'") + Chars.NBSp + String(Iterator) 
					+ ". "+NStr("en = 'Card suffix does not correspond to the template suffix.'; ru = 'Суффикс карты не соответствует суффиксу шаблона.';pl = 'Sufiks karty nie odpowiada sufiksowi szablonu.';es_ES = 'Sufijo de la tarjeta no corresponde al sufijo del modelo.';es_CO = 'Sufijo de la tarjeta no corresponde al sufijo del modelo.';tr = 'Kart eki, şablon ekine uygun değil.';it = 'Suffisso carta non corrisponde con il modello suffisso.';de = 'Das Kartensuffix entspricht nicht dem Vorlagensuffix.'"));
				CheckPassed = False;
			EndIf;
			
			If Left(curRow, StrLen(PatternData["Prefix" + String(Iterator)])) <> PatternData["Prefix" + String(Iterator)] Then
				CommonClientServer.MessageToUser(NStr("en = 'Track'; ru = 'Дорожка';pl = 'Ścieżka';es_ES = 'Seguimiento';es_CO = 'Seguimiento';tr = 'Yol';it = 'Traccia';de = 'Spur'") + Chars.NBSp + String(Iterator) 
					+ ". " + NStr("en = 'Card prefix does not correspond to the template prefix.'; ru = 'Префикс карты не соответствует префиксу шаблона.';pl = 'Prefiks karty nie odpowiada prefiksowi szablonu.';es_ES = 'Prefijo de la tarjeta no corresponde al prefijo del modelo.';es_CO = 'Prefijo de la tarjeta no corresponde al prefijo del modelo.';tr = 'Kart öneki, şablon önekine uygun değil.';it = 'Prefisso carta non corrisponde con il prefisso modello.';de = 'Das Kartenpräfix entspricht nicht dem Vorlagenpräfix.'"));
				CheckPassed = False;
			EndIf;
			
			If Find(curRow, PatternData["BlocksDelimiter"+String(Iterator)]) = 0 Then
				CommonClientServer.MessageToUser(NStr("en = 'Track'; ru = 'Дорожка';pl = 'Ścieżka';es_ES = 'Seguimiento';es_CO = 'Seguimiento';tr = 'Yol';it = 'Traccia';de = 'Spur'") + Chars.NBSp + String(Iterator) 
					+ ". "+NStr("en = 'Card block separator does not correspond to template block separator.'; ru = 'Разделитель блоков карты не соответствует разделителю блоков шаблона.';pl = 'Separator bloków kart nie odpowiada separatorowi bloków szablonów.';es_ES = 'Separador del bloqueo de la tarjeta no corresponde al separador del bloqueo del modelo.';es_CO = 'Separador del bloqueo de la tarjeta no corresponde al separador del bloqueo del modelo.';tr = 'Kart blok ayırıcı, şablon bloğu ayırıcısına karşılık gelmez.';it = 'Il separatore del blocco carta non corrisponde al separatore dei blocchi del template.';de = 'Das Kartenblocktrennzeichen entspricht nicht dem Vorlagenblocktrennzeichen.'"));
				CheckPassed = False;
			EndIf;
				
			If StrLen(curRow) <> PatternData["CodeLength"+String(Iterator)] Then
				CommonClientServer.MessageToUser(NStr("en = 'Track'; ru = 'Дорожка';pl = 'Ścieżka';es_ES = 'Seguimiento';es_CO = 'Seguimiento';tr = 'Yol';it = 'Traccia';de = 'Spur'") + Chars.NBSp + String(Iterator) 
					+ ". " + NStr("en = 'Card code length does not correspond to the template code length.'; ru = 'Длина кода карты не соответствует длине кода шаблона.';pl = 'Długość kodu karty nie odpowiada długości kodu szablonu.';es_ES = 'Longitud del código de la tarjeta no corresponde a la longitud del código del modelo.';es_CO = 'Longitud del código de la tarjeta no corresponde a la longitud del código del modelo.';tr = 'Kart kod uzunluğu, şablon kod uzunluğuna uygun değil.';it = 'Lunghezza del codice della carta non corrisponde con codice del template lunghezza.';de = 'Die Kartencodelänge entspricht nicht der Vorlagencodelänge.'"));
				CheckPassed = False;
			EndIf;
			
			If Not CheckPassed Then
				Return False;
			EndIf;
		EndIf;
	EndDo;
	
	If OneTrackExist Then 
		Return True;
	Else
		CommonClientServer.MessageToUser(NStr("en = 'No available track is specified in the template.'; ru = 'В шаблоне не указано ни одной доступной дорожки.';pl = 'W szablonie nie określono żadnej dostępnej ścieżki.';es_ES = 'No hay un seguimiento disponible especificado en el modelo.';es_CO = 'No hay un seguimiento disponible especificado en el modelo.';tr = 'Şablonda uygun parça belirtilmemiş.';it = 'Nel modello non specificata alcuna traccia disponibile.';de = 'In der Vorlage ist keine verfügbare Spur angegeben.'"));
		Return False;
	EndIf;
	
EndFunction

// Receives events from device.
//
Function GetEventFromDevice(DetailsEvents, ErrorDescription = "") Export
	
	Result = Undefined;
	
	// Searching for an event handler
	For Each Connection In glPeripherals.PeripheralsConnectingParameters Do
						  
		If Connection.EventSource = DetailsEvents.Source
		 Or (IsBlankString(Connection.EventSource)
		   AND Connection.NamesEvents <> Undefined) Then
		   
		   // Look for device with the enabled event among the peripherals.
			Event = Connection.NamesEvents.Find(DetailsEvents.Event);
			If Event <> Undefined Then
				DriverObject = GetDriverObject(Connection);
				If DriverObject = Undefined Then
					// Error message prompting that the driver can not be imported.
					ErrorDescription = NStr("en = '""%Description%"": Cannot export the peripheral driver.
					                        |Check if the driver is correctly installed and registered in the system.'; 
					                        |ru = '%Description%: Не удалось загрузить драйвер устройства.
					                        |Проверьте, что драйвер корректно установлен и зарегистрирован в системе.';
					                        |pl = '""%Description%"": Nie można wyeksportować sterownika urządzenia peryferyjnego.
					                        |Sprawdź, czy sterownik jest poprawnie zainstalowany i zarejestrowany w systemie.';
					                        |es_ES = '""%Description%"": No se puede exportar el driver de periféricos.
					                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
					                        |es_CO = '""%Description%"": No se puede exportar el driver de periféricos.
					                        |Revisar si el driver está instalado de forma correcta y registrado en el sistema.';
					                        |tr = '""%Description%"": Çevre birimi sürücüsü dışa aktarılamıyor.
					                        |Sürücünün sistemde doğru şekilde kurulduğundan ve kayıtlı olduğundan emin olun.';
					                        |it = '%Description%: Non è possibile esportare il driver della periferica.
					                        |Controllare se il driver è installato correttamente e registrato nel sistema.';
					                        |de = '""%Description%"": Der Peripherietreiber kann nicht exportiert werden.
					                        |Überprüfen Sie, ob der Treiber korrekt installiert und im System registriert ist.'");
					ErrorDescription = StrReplace(ErrorDescription, "%Description%", Connection.Description);
					Continue;
				EndIf;
				
				InputParameters  = New Array();
				InputParameters.Add(DetailsEvents.Event);
				InputParameters.Add(DetailsEvents.Data);
				Output_Parameters = Undefined;
				
				// Processing a message
				ProcessingResult = RunCommand(Connection.Ref, "ProcessEvent", InputParameters, Output_Parameters);
				
				If ProcessingResult Then
					// Notify 
					Result = New Structure();
					Result.Insert("EventName", Output_Parameters[0]);
					Result.Insert("Parameter",   Output_Parameters[1]);
					Result.Insert("Source",   "Peripherals");
				EndIf;
				
				// Notify driver on event processor end.
				InputParameters.Clear();
				InputParameters.Add(ProcessingResult);
				RunCommand(Connection.Ref, "FinishProcessingEvents", InputParameters, Output_Parameters);
				
			EndIf;
			
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Processes the event data received from the client.
//
Function ProcessEventFromDevice(DetailsEvents, ErrorDescription = "") Export

	Result = True;
	
	// Searching for an event handler
	For Each Connection In glPeripherals.PeripheralsConnectingParameters Do
						  
		If Connection.EventSource = DetailsEvents.Source
		 Or (IsBlankString(Connection.EventSource)
		   AND Connection.NamesEvents <> Undefined) Then
		   
		   // Look for device with the enabled event among the peripherals.
			Event = Connection.NamesEvents.Find(DetailsEvents.Event);
			If Event <> Undefined Then
				
				DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(Connection.DriverHandler, Not Connection.AsConfigurationPart);
				If DriverHandler = PeripheralsUniversalDriverClientAsynchronously 
					Or DriverHandler = PeripheralsUniversalDriverClient Then
					
					Output_Parameters = New Array();
					// Processing a message
					Result = DriverHandler.ProcessEvent(Undefined, Connection.Parameters, Connection.ConnectionParameters, DetailsEvents.Event, DetailsEvents.Data, Output_Parameters);
					// Processing a message
					If Result Then
						// Notify 
						Notify(Output_Parameters[0], Output_Parameters[1], "Peripherals");
					EndIf;
					
				Else
					
					InputParameters  = New Array();
					InputParameters.Add(DetailsEvents.Event);
					InputParameters.Add(DetailsEvents.Data);
					Output_Parameters = Undefined;
					// Processing a message
					Result = RunCommand(Connection.Ref, "ProcessEvent", InputParameters, Output_Parameters);
					If Result Then
						// Notify 
						Notify(Output_Parameters[0], Output_Parameters[1], "Peripherals");
					EndIf;
				    // Notify driver on event processor end.
					InputParameters.Clear();
					InputParameters.Add(Result);
					RunCommand(Connection.Ref, "FinishProcessingEvents", InputParameters, Output_Parameters);
				EndIf;
			EndIf;
			
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region CommonCommandsProcedures

// Open form of workplaces list.
//
Procedure OpenWorkplaces(CommandParameter, CommandExecuteParameters) Export
	
	RefreshClientWorkplace();
	FormParameters = New Structure();
	OpenForm("Catalog.Workplaces.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

// Procedure for workplace selection of the current session.
//
Procedure SelectCashierWorkPlace(CommandParameter, CommandExecuteParameters) Export
	
	Notification = New NotifyDescription("OfferWorkplaceSelectionEnd", ThisObject);
	OfferWorkplaceSelection(Notification);
	
EndProcedure

// Open peripherals form.
//
Procedure OpenPeripherals(CommandParameter, CommandExecuteParameters) Export
	
	RefreshClientWorkplace();
	
	FormParameters = New Structure();
	OpenForm("Catalog.Peripherals.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

// Open equipment drivers form.
//
Procedure OpenHardwareDrivers(CommandParameter, CommandExecuteParameters) Export
	
	RefreshClientWorkplace();
	
	FormParameters = New Structure();
	OpenForm("Catalog.HardwareDrivers.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region WorkWithDriverProceduresAndFunctions

// Checks if driver is set.
//
Function DriverIsSet(ID) Export
	
	EquipmentData = EquipmentManagerServerCall.GetDeviceData(ID);
	DriverObject = GetDriverObject(EquipmentData);
	
	Return DriverObject <> Undefined;
	
EndFunction

#If Not WebClient Then

// Install or reinstall selected drivers.
//
Procedure ResetMarkedDrivers() Export
	
	SystemInfo = New SystemInfo();
	WorkplacesArray = EquipmentManagerClientReUse.FindWorkplacesById(Upper(SystemInfo.ClientID));
	If WorkplacesArray.Count() = 0 Then
		Workplace = Undefined
	Else
		Workplace = WorkplacesArray[0];
	EndIf;
	
	// Reset drivers marked with check box for resetting.
	If ValueIsFilled(Workplace) Then
		EquipmentList = EquipmentManagerServerCall.GetDriversListForReinstallation(Workplace);
		For Each Equipment In EquipmentList Do
			If Equipment.DriverData.AsConfigurationPart AND Not Equipment.DriverData.SuppliedAsDistribution Then
				BeginInstallAddIn(, "CommonTemplate." + Equipment.DriverData.DriverTemplateName);
			EndIf;
			EquipmentManagerServerCall.SetReinstallSignDrivers(Workplace, Equipment.HardwareDriver, False); 
		EndDo;
	EndIf;
	
	// Install drivers marked to be installed.
	If ValueIsFilled(Workplace) Then
		EquipmentList = EquipmentManagerServerCall.GetDriversListForInstallation(Workplace);
		For Each Equipment In EquipmentList Do
			If Equipment.DriverData.AsConfigurationPart AND Not Equipment.DriverData.SuppliedAsDistribution Then
				DriverObject = GetDriverObject(Equipment.DriverData);
				If DriverObject = Undefined Then
					BeginInstallAddIn(, "CommonTemplate." + Equipment.DriverData.DriverTemplateName);
				Else
					DisconnectDriverObject(Equipment.DriverData);
				EndIf;
			EndIf;
			EquipmentManagerServerCall.SetSignOfDriverInstallation(Workplace, Equipment.HardwareDriver, False); 
		EndDo;
	EndIf;
	
EndProcedure

Procedure StartDriverSettingFromDistributionEnd(Result, Parameters) Export
	
	If Parameters.Property("TempFile") Then
		BeginDeletingFiles(, Parameters.TempFile);
	EndIf;
	If Parameters.Property("InstallationDirectory") Then
		BeginDeletingFiles(, Parameters.InstallationDirectory);
	EndIf;
	
	If Parameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(Parameters.AlertOnEnd, Result = 0);
	EndIf;
	
EndProcedure

// Start the driver installation from the supplier distribution from template.
//
Procedure StartDriverSettingFromDistributionInLayout(AlertOnEnd, TemplateName, FileName) Export
	
	Result = False;
	// Getting a template from the server
	FileReference	= EquipmentManagerServerCall.GetTemplateFromServer(TemplateName);
	FileNameTemp	= ?(IsBlankString(FileName), "setup.exe", FileName);
	
	// StartGetTemporaryFilesDirectory 
	TemporaryDirectory		= TempFilesDir();
	TempFile				= TemporaryDirectory + "Model.zip";
	InstallationDirectory	= TemporaryDirectory + "Model\";
	
	// Unpack the distribution archive into a temporary directory.
	Result = GetFile(FileReference, TempFile, False);
	
	FileOfArchive = New ZipFileReader();
	FileOfArchive.Open(TempFile);
	
	If FileOfArchive.Items.Find(FileNameTemp) <> Undefined Then
		// Unpack distribution
		FileOfArchive.ExtractAll(InstallationDirectory);
		FileOfArchive.Close();
		
		// Run installation
		Parameters		= New Structure("InstallationDirectory, TempFile, AlertOnEnd", InstallationDirectory, TempFile, AlertOnEnd);
		Notification	= New NotifyDescription("StartDriverSettingFromDistributionEnd", ThisObject, Parameters);
		BeginRunningApplication(Notification, InstallationDirectory + FileNameTemp, InstallationDirectory, True);
		
	Else
		
		CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred while setting driver from distributive in template.
			     |File %1 is not found in template.'; 
			     |ru = 'Ошибка установки драйвера из дистрибутива в макете.
			     |Файл ""%1"" в макете не найден.';
			     |pl = 'Wystąpił błąd podczas ustawiania sterownika z dystrybucji w szablonie.
			     |Plik %1 nie został znaleziony w szablonie.';
			     |es_ES = 'Ha ocurrido un error al configurar el driver desde el distributivo en el modelo.
			     |Archivo %1 no encontrado en el modelo.';
			     |es_CO = 'Ha ocurrido un error al configurar el driver desde el distributivo en el modelo.
			     |Archivo %1 no encontrado en el modelo.';
			     |tr = 'Sürücüyü şablonda dağıtımdan ayarlarken bir hata oluştu. 
			     |Dosya %1şablonda bulunamadı.';
			     |it = 'Un errore si è registrato durante l''impostazione dei driver dal distributore nel layout.
			     |Il file %1 non è stato trovato nel layout.';
			     |de = 'Beim Festlegen des Treibers von distributiv in der Vorlage ist ein Fehler aufgetreten.
			     |Die Datei%1 wurde nicht in der Vorlage gefunden.'"),
			FileNameTemp));
			
		BeginDeletingFiles(, TempFile);
		If AlertOnEnd <> Undefined Then
			ExecuteNotifyProcessing(AlertOnEnd, False);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure StartDriverSettingFromDistributionFromBaseEnd(Result, Parameters) Export
	
	BeginDeletingFiles(, Parameters.TemporaryDirectory + "Model\");
	BeginDeletingFiles(, Parameters.TemporaryDirectory + "Model.zip");
	
	If Parameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(Parameters.AlertOnEnd, Result = 0);
	EndIf;
	
EndProcedure

// Start setting driver from distributive of vendor from base.
//
Procedure StartDriverSettingFromBaseDistribution(AlertOnEnd, DriverData) Export
	
	Result = False;
	
	TemporaryDirectory   = TempFilesDir();
	FileNameTemp       = TemporaryDirectory + DriverData.DriverFileName;
	InstallationDirectory = TemporaryDirectory + "Model\";
	
	GetFile(GetURL(DriverData.HardwareDriver, "ExportedDriver"), FileNameTemp, False);
	TempFile = New File(FileNameTemp);
	
	If Upper(TempFile.Extension) = ".ZIP" Then
		// Unpack distribution
		FileOfArchive = New ZipFileReader();
		FileOfArchive.Open(TempFile.FullName);
		
		InstalledFileName = "";
		If FileOfArchive.Items.Find(TempFile.BaseName  + ".EXE") <> Undefined Then
			InstalledFileName = TempFile.BaseName  + ".EXE";
		ElsIf FileOfArchive.Items.Find("setup.exe") <> Undefined Then
			InstalledFileName = "setup.exe";
		EndIf;
		
		If Not IsBlankString(InstalledFileName) Then
			// Unpack distribution
			FileOfArchive.ExtractAll(InstallationDirectory);
			FileOfArchive.Close();
			// Run installation
			Parameters = New Structure("InstallationDirectory, TempFile, AlertOnEnd", InstallationDirectory, FileNameTemp, AlertOnEnd);
			Notification = New NotifyDescription("StartDriverSettingFromDistributionEnd", ThisObject, Parameters);
			BeginRunningApplication(Notification, InstallationDirectory + InstalledFileName, InstallationDirectory, True);
		Else
			FileOfArchive.Close();
			ErrorText = NStr("en = 'An error occurred while setting driver from distributive in archive.
			                 |Required file is not found in archive.'; 
			                 |ru = 'Ошибка установки драйвера из дистрибутива в архиве.
			                 |Необходимый файл в архиве не найден.';
			                 |pl = 'Wystąpił błąd podczas ustawiania sterownika z dystrybucji w archiwum.
			                 |Wymagany plik nie został znaleziony w archiwum.';
			                 |es_ES = 'Ha ocurrido un error al configurar el driver desde el distributivo en el archivo.
			                 |Documento requerido no encontrado en el archivo.';
			                 |es_CO = 'Ha ocurrido un error al configurar el driver desde el distributivo en el archivo.
			                 |Documento requerido no encontrado en el archivo.';
			                 |tr = 'Sürücüyü arşivde dağıtmadan ayarlarken bir hata oluştu. 
			                 |Gerekli dosya arşivde bulunamadı.';
			                 |it = 'Si è verificato un errore durante l''impostazione del driver da distributivo in archivio. 
			                 |Il file richiesto non è stato trovato nell''archivio.';
			                 |de = 'Beim Festlegen des Treibers von distributiv im Archiv ist ein Fehler aufgetreten.
			                 |Die erforderliche Datei wurde nicht im Archiv gefunden.'");
			CommonClientServer.MessageToUser(ErrorText); 
			BeginDeletingFiles(, FileNameTemp);
		EndIf;
	Else
		// Run installation
		Parameters = New Structure("TempFile, AlertOnEnd", FileNameTemp, AlertOnEnd);
		Notification = New NotifyDescription("StartDriverSettingFromDistributionEnd", ThisObject, Parameters);
		BeginRunningApplication(Notification, TemporaryDirectory + FileNameTemp, TemporaryDirectory, True);
	EndIf;
	
EndProcedure

#EndIf

// Disconnecting a driver object.
//
Procedure DisconnectDriverObject(DriverData) Export

	ArrayLineNumber = glPeripherals.PeripheralsConnectingParameters.Find(DriverData.HardwareDriver);
	If ArrayLineNumber <> Undefined Then
		glPeripherals.PeripheralsConnectingParameters.Delete(ArrayLineNumber);
	EndIf;
	
EndProcedure

// Getting a driver object
//
Function GetDriverObject(DriverData, ErrorText = Undefined) Export
	
	DriverObject = Undefined;
	
	For Each Driver In glPeripherals.PeripheralsDrivers Do
		If Driver.Key = DriverData.HardwareDriver  Then
			DriverObject = Driver.Value;
			Break;
		EndIf;
	EndDo;   
	
	If DriverObject = Undefined Then
		Try
			
			ProgID = DriverData.ObjectID;
			
			ThisIsCOMObject = False;
			If Find(ProgID, "COMObject") > 0 Then
				
				ThisIsCOMObject = True;
				ProgID = Mid(ProgID, 11);
			EndIf;

			If IsBlankString(ProgID) Then
				DriverObject = ""; // Driver is not required
			Else
				ProgID1 = ?(Find(ProgID, "|") > 0, Mid(ProgID, 1, Find(ProgID, "|")-1), ProgID); 
				ProgID2 = ?(Find(ProgID, "|") > 0, Mid(ProgID, Find(ProgID, "|")+1), ProgID); 
				If DriverData.SuppliedAsDistribution Then
					AttachAddIn(ProgID1);
				Else
					ObjectName = Mid(ProgID1, Find(ProgID1, ".") + 1); 
					Prefix = Mid(ProgID1, 1, Find(ProgID1, ".")); 
					ProgID2 = Prefix + StrReplace(ObjectName, ".", "_") + "." + ObjectName;
					If DriverData.AsConfigurationPart Then
						Result = AttachAddIn("CommonTemplate." + DriverData.DriverTemplateName, StrReplace(ObjectName, ".", "_"));
					Else
						DriverLink = GetURL(DriverData.HardwareDriver, "ExportedDriver");
						Result = AttachAddIn(DriverLink, StrReplace(ObjectName, ".", "_"));
					EndIf;
				EndIf;
				
				If ThisIsCOMObject Then
					DriverObject = New COMObject(ProgID2);
				Else
					DriverObject = New (ProgID2);
				EndIf;
				
			EndIf;
				
		Except
			Info = ErrorInfo();
			ErrorText = Info.Description;
		EndTry;
		
		If DriverObject <> Undefined Then
			glPeripherals.PeripheralsDrivers.Insert(DriverData.HardwareDriver, DriverObject);
			DriverObject = glPeripherals.PeripheralsDrivers[DriverData.HardwareDriver];
		EndIf;
		
	EndIf;   
		
	Return DriverObject;
	
EndFunction

Procedure StartReceiveDriverObjectEnd(Attached, AdditionalParameters) Export
	
	DriverObject = Undefined;
	
	If Attached Then 
		Try
			DriverObject = New (AdditionalParameters.ProgID);
			If DriverObject <> Undefined Then
				glPeripherals.PeripheralsDrivers.Insert(AdditionalParameters.HardwareDriver, DriverObject);
				DriverObject = glPeripherals.PeripheralsDrivers[AdditionalParameters.HardwareDriver];
			EndIf;
			ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, DriverObject);
			Return;
		Except
		EndTry;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, Undefined);
	
EndProcedure

// Start receiving driver object.
//
Procedure StartReceivingDriverObject(AlertOnEnd, DriverData) Export
	
	DriverObject = Undefined;
	
	For Each Driver In glPeripherals.PeripheralsDrivers Do
		If Driver.Key = DriverData.HardwareDriver  Then
			DriverObject = Driver.Value;
			ExecuteNotifyProcessing(AlertOnEnd, DriverObject);
			Return;
		EndIf;
	EndDo;   
	
	If DriverObject = Undefined Then
			ProgID = DriverData.ObjectID;
			If IsBlankString(ProgID) Then
				DriverObject = ""; // Driver is not required
				ExecuteNotifyProcessing(AlertOnEnd, DriverObject);
			Else
				ProgID1 = ?(Find(ProgID, "|") > 0, Mid(ProgID, 1, Find(ProgID, "|")-1), ProgID); 
				ProgID2 = ?(Find(ProgID, "|") > 0, Mid(ProgID, Find(ProgID, "|")+1), ProgID); 
				
				If DriverData.SuppliedAsDistribution Then
					Parameters = New Structure("ProgID, AlertOnEnd, HardwareDriver", ProgID2, AlertOnEnd, DriverData.HardwareDriver);
					Notification = New NotifyDescription("StartReceiveDriverObjectEnd", ThisObject, Parameters);
					BeginAttachingAddIn(Notification, ProgID1);
				Else
					ObjectName = Mid(ProgID1, Find(ProgID1, ".") + 1); 
					Prefix = Mid(ProgID1, 1, Find(ProgID1, ".")); 
					ProgID2 = Prefix + StrReplace(ObjectName, ".", "_") + "." + ObjectName;
					
					Parameters = New Structure("ProgID, AlertOnEnd, HardwareDriver", ProgID2, AlertOnEnd, DriverData.HardwareDriver);
					Notification = New NotifyDescription("StartReceiveDriverObjectEnd", ThisObject, Parameters);
					If DriverData.AsConfigurationPart Then
						BeginAttachingAddIn(Notification, "CommonTemplate." + DriverData.DriverTemplateName, StrReplace(ObjectName, ".", "_"));
					Else
						DriverLink = GetURL(DriverData.HardwareDriver, "ExportedDriver");
						BeginAttachingAddIn(Notification, DriverLink, StrReplace(ObjectName, ".", "_"));
					EndIf;
				EndIf;
				
			EndIf;
	EndIf;   
	
EndProcedure

// Set equipment driver.
//
Procedure SetupDriver(ID, AlertFromDistributionOnEnd = Undefined, AlertFromArchiveOnEnd = Undefined) Export
	
	DriverData = EquipmentManagerServerCall.GetDriverData(ID);
	
	Try
		If DriverData.SuppliedAsDistribution Then
			#If WebClient Then
				CommonClientServer.MessageToUser(NStr("en = 'This driver is not supported in the web client.'; ru = 'Данный драйвер не поддерживает работу в веб-клиенте.';pl = 'Ten sterownik nie jest obsługiwany w kliencie webowym.';es_ES = 'El driver no está admitido en el cliente web.';es_CO = 'El driver no está admitido en el cliente web.';tr = 'Bu sürücü web istemcisinde desteklenmiyor.';it = 'Questo driver non supporta il lavoro del client web.';de = 'Dieser Treiber wird im Webclient nicht unterstützt.'")); 
			#Else
				If EquipmentManagerClientReUse.IsLinuxClient() Then
					CommonClientServer.MessageToUser(NStr("en = 'The driver cannot be installed and used in the Linux environment.'; ru = 'Данный драйвер не может быть установлен и использован в среде Linux.';pl = 'Sterownik nie można zainstalowany i używany w środowisku Linux.';es_ES = 'El driver no puede instalarse y utilizarse en el entorno de Linux.';es_CO = 'El driver no puede instalarse y utilizarse en el entorno de Linux.';tr = 'Sürücü Linux ortamında yüklenemez ve kullanılamaz.';it = 'Questo driver non può essere installato e utilizzato in un ambiente Linux.';de = 'Der Treiber kann nicht in der Linux-Umgebung installiert und verwendet werden.'")); 
					Return;
				EndIf;
				StartDriverSettingFromBaseDistribution(AlertFromDistributionOnEnd, DriverData);
			#EndIf
		Else
			If Not IsBlankString(DriverData.DriverTemplateName) Then
				DriverLink = "CommonTemplate." + DriverData.DriverTemplateName;
			Else
				DriverLink = GetURL(DriverData.HardwareDriver, "ExportedDriver");
			EndIf;
		
			BeginInstallAddIn(AlertFromArchiveOnEnd, DriverLink);
		EndIf;
		
	Except
		CommonClientServer.MessageToUser(NStr("en = 'An error occurred while installing the driver.'; ru = 'Произошла ошибка при установке драйвера.';pl = 'Wystąpił błąd podczas instalacji sterownika.';es_ES = 'Ha ocurrido un error al instalar el driver.';es_CO = 'Ha ocurrido un error al instalar el driver.';tr = 'Sürücü yürütülürken bir hata oluştu.';it = 'Si è verificato un errore durante l''installazione del driver.';de = 'Bei der Installation des Treibers ist ein Fehler aufgetreten.'")); 
	EndTry;  
		
EndProcedure

#EndRegion