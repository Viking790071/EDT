#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		
		ModuleSafeModeManager   = Common.CommonModule("SafeModeManager");
		UseSecurityProfiles = ModuleSafeModeManager.UseSecurityProfiles();
		
	Else
		UseSecurityProfiles = False;
	EndIf;
	
	If Not AdditionalProperties.Property("SkipBasicFillingCheck") Then
	
		If Not SequenceNumberUnique(FillOrder, Ref) Then
			ErrorText = NStr("ru = 'Порядок заполнения не уникален - в системе уже есть том с таким порядком'; en = 'Fill order is not unique. There is a volume of the same order.'; pl = 'Tryb wypełnienia nie jest unikalny - w systemie już jest tom z takim trybem';es_ES = 'Orden de relleno no es único. Volumen con este orden ya existe en el sistema';es_CO = 'Orden de relleno no es único. Volumen con este orden ya existe en el sistema';tr = 'Doldurma sırası benzersiz değil. Sistemde böyle bir düzene sahip disk bölümü zaten var';it = 'Compilazione ordine non univoca. C''è un volume per lo stesso ordine.';de = 'Die Füllreihenfolge ist nicht eindeutig. Das Volumen mit dieser Reihenfolge ist bereits im System vorhanden'");
			CommonClientServer.MessageToUser(ErrorText, , "FillOrder", "Object", Cancel);
		EndIf;
		
		If MaxSize <> 0 Then
			CurrentSizeInBytes = 0;
			If Not Ref.IsEmpty() Then
				CurrentSizeInBytes = FilesOperationsInternalServerCall.CalculateFileSizeInVolume(Ref);
			EndIf;
			ActualSize = CurrentSizeInBytes / (1024 * 1024);
			
			If MaxSize < ActualSize Then
				ErrorText = NStr("ru = 'Максимальный размер тома меньше, чем текущий размер'; en = 'Max volume size is less than the current one'; pl = 'Maksymalny rozmiar tomu jest mniejszy niż bieżący rozmiar';es_ES = 'Tamaño máximo del volumen es menor al tamaño actual';es_CO = 'Tamaño máximo del volumen es menor al tamaño actual';tr = 'Disk bölümün maksimum boyutu geçerli boyuttan daha küçüktür';it = 'Il volume massimo è inferiore a quello attuale';de = 'Die maximale Größe des Volumens ist kleiner als die aktuelle Größe'");
				CommonClientServer.MessageToUser(ErrorText, , "MaxSize", "Object", Cancel);
			EndIf;
		EndIf;
		
		If IsBlankString(FullPathWindows) AND IsBlankString(FullPathLinux) Then
			ErrorText = NStr("ru = 'Не заполнен полный путь'; en = 'Full path is required'; pl = 'Pełna ścieżka nie jest wypełniona';es_ES = 'Ruta completa no se ha introducido';es_CO = 'Ruta completa no se ha introducido';tr = 'Tam yol girilmedi';it = 'Il percorso completo è richiesto';de = 'Der vollständige Pfad wurde nicht eingegeben'");
			CommonClientServer.MessageToUser(ErrorText, , "FullPathWindows", "Object", Cancel);
			CommonClientServer.MessageToUser(ErrorText, , "FullPathLinux",   "Object", Cancel);
			Return;
		EndIf;
		
		If Not UseSecurityProfiles
		   AND Not IsBlankString(FullPathWindows)
		   AND (    Left(FullPathWindows, 2) <> "\\"
		      OR StrFind(FullPathWindows, ":") <> 0 ) Then
			
			ErrorText = NStr("ru = 'Путь к тому должен быть в формате UNC (\\servername\resource).'; en = 'Path to volume should have UNC-format (\\servername\resource).'; pl = 'Ścieżka do woluminu musi mieć format UNC (\\servername\resource).';es_ES = 'Ruta para el volumen tiene que tener el formato UNC (\\ nombredelservidor\recurso).';es_CO = 'Ruta para el volumen tiene que tener el formato UNC (\\ nombredelservidor\recurso).';tr = 'Disk bölümü yolu UNC biçiminde olmalıdır ((\\servername\resource).';it = 'Il percorso al volume deve essere in formato UNC (\\servername\resource).';de = 'Der Pfad zum Volumen muss das UNC-Format haben (\\ Servername \ Ressource).'");
			CommonClientServer.MessageToUser(ErrorText, , "FullPathWindows", "Object", Cancel);
			Return;
		EndIf;
	EndIf;
	
	If Not AdditionalProperties.Property("SkipDirectoryAccessCheck") Then
		FullPathFieldName = "";
		FullVolumePath = "";
		
		SystemInfo = New SystemInfo;
		ServerPlatformType = SystemInfo.PlatformType;
		If ServerPlatformType = PlatformType.Windows_x86
		 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
			
			FullVolumePath = FullPathWindows;
			FullPathFieldName = "FullPathWindows";
		Else
			FullVolumePath = FullPathLinux;
			FullPathFieldName = "FullPathLinux";
		EndIf;
		
		TestDirectoryName = FullVolumePath + "CheckAccess" + GetPathSeparator();
		
		Try
			CreateDirectory(TestDirectoryName);
			DeleteFiles(TestDirectoryName);
		Except
			ErrorInformation = ErrorInfo();
			
			If UseSecurityProfiles Then
				ErrorTemplate =
					NStr("ru = 'Путь к тому некорректен.
					           |Возможно не настроены разрешения в профилях безопасности,
					           |или учетная запись, от лица которой работает
					           |сервер 1С:Предприятия, не имеет прав доступа к каталогу тома.
					           |
					           |%1'; 
					           |en = 'Path to the volume is incorrect.
					           |Permissions might not be set in security profiles, 
					           |or an account on whose behalf 1C: Enterprise server is running 
					           |might not have access rights to the volume directory.
					           |
					           |%1'; 
					           |pl = 'Ścieżka do woluminu jest nieprawidłowa.
					           |Być może nie ustawiono uprawnień w profilach bezpieczeństwa,
					           |lub konto, w imieniu którego pracuje
					           |serwer 1C:Enterprise, nie posiada praw dostępu do katalogu woluminu.
					           |
					           |%1';
					           |es_ES = 'La ruta al tomo no es correcta.
					           |Es posible que no se hayan ajustado las extensiones en los perfiles de seguridad
					           |o la cuenta que usa
					           |el servidor de 1C:Enterprise no tenga derechos de acceso al catálogo del tomo.
					           |
					           |%1';
					           |es_CO = 'La ruta al tomo no es correcta.
					           |Es posible que no se hayan ajustado las extensiones en los perfiles de seguridad
					           |o la cuenta que usa
					           |el servidor de 1C:Enterprise no tenga derechos de acceso al catálogo del tomo.
					           |
					           |%1';
					           |tr = 'Birim yolu doğru değil. 
					           |Güvenlik profillerinde izin verilmeyebilir veya 
					           |1C:Enterprise adına çalıştığı 
					           |hesap, birim dizinine erişim iznine sahip olmayabilir. 
					           |
					           |%1';
					           |it = 'Il percorso al volume è errato. 
					           |I permessi potrebbero non essere impostati nei profili di sicurezza, 
					           |o un account in base al quale il server di 1C: Enterprise è in esecuzione
					           |potrebbe non avere i diritti di accesso alla directory di volume.
					           |
					           |%1';
					           |de = 'Der Pfad zum Volumen ist falsch.
					           |Möglicherweise sind die Berechtigungen in den Sicherheitsprofilen nicht konfiguriert,
					           |oder das Konto, für das der
					           |1C:Enterprise-Server ausgeführt wird, verfügt nicht über Zugriffsrechte für das Volumen-Verzeichnis.
					           |
					           |%1'");
			Else
				ErrorTemplate =
					NStr("ru = 'Путь к тому некорректен.
					           |Возможно учетная запись, от лица которой работает
					           |сервер 1С:Предприятия, не имеет прав доступа к каталогу тома.
					           |
					           |%1'; 
					           |en = 'Path to the volume is incorrect.
					           |An account on whose behalf 1C: Enterprise server is running 
					           |might not have access rights to the volume directory.
					           |
					           |%1'; 
					           |pl = 'Ścieżka do woluminu jest nieprawidłowa.
					           |Być może konto, w imieniu którego pracuje
					           |serwer 1C:Enterprise, nie posiada praw dostępu do katalogu woluminu.
					           |
					           |%1';
					           |es_ES = 'La ruta al tomo no es correcta.
					           |Es posible que la cuenta que usa
					           |el servidor de 1C:Enterprise no tenga derechos de acceso al catálogo del tomo.
					           |
					           |%1';
					           |es_CO = 'La ruta al tomo no es correcta.
					           |Es posible que la cuenta que usa
					           |el servidor de 1C:Enterprise no tenga derechos de acceso al catálogo del tomo.
					           |
					           |%1';
					           |tr = 'Birim yolu doğru değil. 
					           |1C:Enterprise sunucusunun 
					           |çalıştığı hesap, disk bölümü dizinine erişim haklarına sahip değildir. 
					           |
					           |%1';
					           |it = 'Il percorso al volume è errato.
					           |Un account in base al quale il server di 1C: Enterprise è in esecuzione
					           |potrebbe non avere i diritti di accesso alla directory di volume.
					           |
					           |%1';
					           |de = 'Der Pfad zum Volumen ist falsch.
					           |Es ist möglich, dass das Konto, für das der
					           |1C:Enterprise-Server ausgeführt wird, keine Zugriffsrechte für das Volumen-Verzeichnis hat.
					           |
					           |%1'");
			EndIf;
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				ErrorTemplate, BriefErrorDescription(ErrorInformation));
			
			CommonClientServer.MessageToUser(
				ErrorText, , FullPathFieldName, "Object", Cancel);
		EndTry;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Returns False if there is a volume of the same order.
Function SequenceNumberUnique(FillOrder, VolumeRef)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(Volumes.FillOrder) AS Count
	|FROM
	|	Catalog.FileStorageVolumes AS Volumes
	|WHERE
	|	Volumes.FillOrder = &FillOrder
	|	AND Volumes.Ref <> &VolumeRef";
	
	Query.Parameters.Insert("FillOrder", FillOrder);
	Query.Parameters.Insert("VolumeRef", VolumeRef);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Count = 0;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#EndIf