#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification
// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	AttributesToEdit = New Array;
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// SaaSTechnology.ExportImportData

// Returns the catalog attributes that naturally form a catalog item key.
//
// Returns:
//  Array (String) - an array of attribute names that form a natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array;
	Result.Add("FullName");
	
	Return Result;
	
EndFunction

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#Region Internal

// For internal use only.
Procedure CheckForUsage(ExtensionsObjects = False) Export
	
	If StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Справочник ""%1"" не используется.'; en = 'The ""%1"" catalog is not used.'; pl = 'Katalog ""%1"" nie jest używany.';es_ES = 'Catálogo ""%1"" no se ha utilizado';es_CO = 'Catálogo ""%1"" no se ha utilizado';tr = 'Katalog ""%1"" kullanılmamaktadır.';it = 'L''anagrafica ""%1"" non è usata.';de = 'Verzeichnis ""%1"" wird nicht verwendet.'"), CatalogDescription(ExtensionsObjects));
	EndIf;
	
	If ExtensionsObjects AND Not Common.SeparatedDataUsageAvailable() Then
		Raise ExtensionObjectsIDsUnvailableInSharedModeErrorDescription();
	EndIf;
	
	SetPrivilegedMode(True);
	
	If ExchangePlans.MasterNode() = Undefined
	   AND ValueIsFilled(Common.ObjectManagerByFullName("Constant.MasterNode").Get()) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Справочник ""%1"" не может использоваться
			           |в информационной базе с неподтвержденной отменой главного узла.
			           |
			           |Для восстановления связи с главным узлом запустите 1С:Предприятие и
			           |нажмите кнопку Восстановить или программно установите главный узел,
			           |сохраненный в константе Главный узел.
			           |
			           |Для подтверждения отмены связи с главным узлом запустите 1С:Предприятие и
			           |нажмите кнопку Отключить или программно очистите константу Главный узел.'; 
			           |en = 'The ""%1"" catalog cannot be used
			           |in the infobase where the detachment of the master node is not confirmed. 
			           |
			           |To attach the infobase back to the maser node, start 1C:Enterprise
			           |and click ""Attach"", or set the master node programmatically
			           |(it is stored in the ""Master node"" constant).
			           |
			           |To confirm the detachment of the master node, start 1C:Enterprise and
			           |click ""Detach"", or clear the ""Master node"" constant programmatically.'; 
			           |pl = 'Katalog ""%1"" nie może być użyty
			           |w bazie informacyjnej, gdzie odłączenie węzła głównego nie jest potwierdzone. 
			           |
			           |Aby dołączyć bazę informacyjną z powrotem do węzła maser, uruchom 1C:Enterprise
			           |i kliknij ""Dołącz"" lub ustaw węzeł główny programowo
			           |(jest on przechowywany w stałej ""Węzeł główny"").
			           |
			           |Aby potwierdzić odłączenie węzła głównego, uruchom 1C:Enterprise i
			           |kliknij ""Odłącz"" lub wyczyść programowo ""Węzeł główny"".';
			           |es_ES = 'El catálogo ""%1"" no puede utilizarse
			           |en la infobase con la cancelación no confirmada del nodo principal.
			           |
			           |Para restablecer la conexión con el nodo principal lance 1C:Enterprise y
			           |haga clic en el botón Restablecer, o instale el nodo principal a través del programa
			           |guardado en la constante Nodo principal.
			           |
			           |Para confirmar que quiere cancelar la conexión con el nodo principal, lanzar 1C:Enterprise y
			           |hacer clic en el botón Desactivar, o la aplicación de eliminar automáticamente la constante del Nodo principal.';
			           |es_CO = 'El catálogo ""%1"" no puede utilizarse
			           |en la infobase con la cancelación no confirmada del nodo principal.
			           |
			           |Para restablecer la conexión con el nodo principal lance 1C:Enterprise y
			           |haga clic en el botón Restablecer, o instale el nodo principal a través del programa
			           |guardado en la constante Nodo principal.
			           |
			           |Para confirmar que quiere cancelar la conexión con el nodo principal, lanzar 1C:Enterprise y
			           |hacer clic en el botón Desactivar, o la aplicación de eliminar automáticamente la constante del Nodo principal.';
			           |tr = 'Master düğüm ayrılmasının doğrulanmadığı Infobase''de
			           |""%1"" kataloğu kullanılamaz.
			           |
			           |Infobase''i master düğüme geri eklemek için 1C:Enterprise''ı çalıştırıp,
			           |""Ekle""ye tıklayın veya master düğümü programlamayla ayarlayın
			           |(""Master düğüm"" sabitinde bulunur).
			           |
			           |Master düğüm ayrılmasını doğrulamak için 1C:Enterprise''ı çalıştırıp,
			           |""Ayır""a tıklayın veya ""Master düğüm"" sabitini programlamayla temizleyin.';
			           |it = 'L''elenco ""%1"" non può essere usato
			           |in un database informatico con un annullamento del nodo principale non confermato. 
			           |
			           |Per il ripristino del collegamento con il nodo principale avviate 1C:Enterprise e
			           |premete il bottone Ripristina oppure ripristinate a livello di codice il nodo principale, 
			           |salvato nella costante Nodo principale.
			           |
			           |Per la conferma del annullamento della connessione con il nodo principale avviate 1C:Enterprise e
			           |premete il bottone Disattivare oppure cancellate a livello di codice la costante Nodo principale.';
			           |de = 'Das Verzeichnis ""%1"" kann nicht
			           |in der Informationsbasis verwendet werden, wenn der Hauptknoten unbestätigt gelöscht wird.
			           |
			           |Um die Verbindung mit dem Hauptknoten wiederherzustellen, starten Sie 1C:Enterprise und
			           |drücken Sie die Schaltfläche Wiederherstellen, oder installieren Sie den in der Konstante Hauptknoten
			           |gespeicherten Hauptknoten.
			           |
			           |Um zu bestätigen, dass Sie die Verbindung mit dem Hauptknoten beenden möchten, starten Sie 1C:Enterprise und
			           |drücken Sie die Schaltfläche Deaktivieren oder löschen Sie die Hauptknotenkonstante programmgesteuert.'"),
			CatalogDescription(ExtensionsObjects));
	EndIf;
	
EndProcedure

// Returns True if the check, update, and search for duplicates are completed.
//
// Parameters:
//  Update - Boolean - if True, tries to update the data.
//              If fails, an exception is thrown.
//             If False, the function returns the data state.
//
Function IsDataUpdated(Update = False, ExtensionsObjects = False) Export
	
	Try
		Updated = StandardSubsystemsServer.ApplicationParameter(
			"StandardSubsystems.Core.MetadataObjectIDs");
	Except
		If Update Then
			Raise;
		EndIf;
		Return False;
	EndTry;
	
	If Updated = Undefined Then
		If Update Then
			UpdateCatalogData();
		Else
			Return False;
		EndIf;
	EndIf;
	
	If ExtensionsObjects
	   AND ValueIsFilled(SessionParameters.AttachedExtensions) Then
		
		If Not Common.SeparatedDataUsageAvailable() Then
			If Update Then
				Raise ExtensionObjectsIDsUnvailableInSharedModeErrorDescription();
			Else
				Return False;
			EndIf;
		EndIf;
		
		If Not Catalogs.ExtensionObjectIDs.CurrentVersionExtensionObjectIDsFilled() Then
			Catalogs.ExtensionObjectIDs.UpdateCatalogData();
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// For internal use only.
//
// Parameters:
//  Objects - Array - of CatalogObject.MetadataObjectIDs to be imported.
//            
//
Procedure ImportDataToSubordinateNode(Objects) Export
	
	If Common.DataSeparationEnabled() Then
		// Not supported in SaaS mode.
		Return;
	EndIf;
	
	If Not Common.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	CheckForUsage();
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	Lock = New DataLock;
	Lock.Add("Catalog.MetadataObjectIDs");
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		// Preparing the outgoing table with renaming for searching for duplicates.
		DataExported = ExportAllIDs();
		DataExported.Columns.Add("DuplicateUpdated", New TypeDescription("Boolean"));
		DataExported.Columns.Add("FullNameLowerCase", New TypeDescription("String"));
		
		// Applying a filter to the objects to be imported. The filter returns only objects that differ from the existing ones.
		ItemsToImportTable = New ValueTable;
		ItemsToImportTable.Columns.Add("Object");
		ItemsToImportTable.Columns.Add("Ref");
		ItemsToImportTable.Columns.Add("MetadataObjectByKey");
		ItemsToImportTable.Columns.Add("MetadataObjectByFullName");
		ItemsToImportTable.Columns.Add("Matches", New TypeDescription("Boolean"));
		
		For each Object In Objects Do
			ItemToImportProperties = ItemsToImportTable.Add();
			ItemToImportProperties.Object = Object;
			
			If ValueIsFilled(Object.Ref) Then
				ItemToImportProperties.Ref = Object.Ref;
			Else
				ItemToImportProperties.Ref = Object.GetNewObjectRef();
				If Not ValueIsFilled(ItemToImportProperties.Ref) Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Ошибка загрузки идентификаторов объектов метаданных.
						           |Невозможно загрузить новый элемент у которого не указана ссылка нового:
						           |""%1"".'; 
						           |en = 'Metadata object ID import error.
						           |Cannot import a new item because its UUID is not specified:
						           |""%1"".'; 
						           |pl = 'Wystąpił błąd podczas importowania identyfikatorów obiektów metadanych.
						           |Nie można zaimportować nowego elementu, w którym
						           |nie określono nowego odwołania: ""%1"".';
						           |es_ES = 'Ha ocurrido un error al importar los identificadores de los objetos de metadatos.
						           |No se puede importar un nuevo artículo en el cual la referencia de
						           |uno nuevo no está especificada: ""%1"".';
						           |es_CO = 'Ha ocurrido un error al importar los identificadores de los objetos de metadatos.
						           |No se puede importar un nuevo artículo en el cual la referencia de
						           |uno nuevo no está especificada: ""%1"".';
						           |tr = 'Meta veri nesneleri kimlikleri içe aktarılırken bir hata oluştu. 
						           |Yeni bir öğe belirtilmemişse %1 yeni öğe içe aktarılamıyor: 
						           |"".';
						           |it = 'Errore durante il caricamento degli identificatori degli oggetti dei metadati.
						           |Impossibile caricare un nuovo elemento nel quale non è specificato il collegamento al nuovo:
						           |""%1"".';
						           |de = 'Beim Importieren von Metadatenobjekt-IDs ist ein Fehler aufgetreten.
						           |Es konnte kein neuer Artikel importiert werden, in dem ref
						           |nicht angegeben wurde: ""%1"".'"),
						Object.FullName);
				EndIf;
			EndIf;
			
			// Preprocessing.
			
			If Not IsCollection(ItemToImportProperties.Ref) Then
				ItemToImportProperties.MetadataObjectByKey = MetadataObjectByKey(
					Object.MetadataObjectKey.Get());
				
				ItemToImportProperties.MetadataObjectByFullName =
					MetadataFindByFullName(Object.FullName);
				
				If ItemToImportProperties.MetadataObjectByKey = Undefined
				   AND ItemToImportProperties.MetadataObjectByFullName = Undefined
				   AND Object.DeletionMark <> True Then
					// If for some reason the object to be imported is not found in the metadata, it must be marked for 
					// deletion.
					Object.DeletionMark = True;
				EndIf;
			EndIf;
			
			If Object.DeletionMark Then
				// Objects marked for deletion cannot have correct full names, hence, to ensure this condition, the 
				// update procedure of the marked for deletion object properties are applied before the import.
				// 
				UpdateMarkedForDeletionItemProperties(Object);
			EndIf;
			
			Properties = DataExported.Find(ItemToImportProperties.Ref, "Ref");
			If Properties <> Undefined
			   AND Properties.Description              = Object.Description
			   AND Properties.Parent                  = Object.Parent
			   AND Properties.CollectionOrder          = Object.CollectionOrder
			   AND Properties.Name                       = Object.Name
			   AND Properties.Synonym                   = Object.Synonym
			   AND Properties.FullName                 = Object.FullName
			   AND Properties.FullSynonym             = Object.FullSynonym
			   AND Properties.NoData                 = Object.NoData
			   AND Properties.EmptyRefValue      = Object.EmptyRefValue
			   AND Properties.PredefinedDataName = Object.PredefinedDataName
			   AND Properties.DeletionMark           = Object.DeletionMark
			   AND IdenticalMetadataObjectKeys(Properties, Object) Then
				
				ItemToImportProperties.Matches = True;
			EndIf;
			
			If Properties <> Undefined Then
				DataExported.Delete(Properties); // Renaming items to be imported is not required.
			EndIf;
		EndDo;
		ItemsToImportTable.Indexes.Add("Ref");
		
		// Renaming the existing items (except for items to be overwritten during the import) to search for duplicates.
		
		RenameFullNames(DataExported);
		For each Row In DataExported Do
			Row.FullNameLowerCase = Lower(Row.FullName);
		EndDo;
		DataExported.Indexes.Add("MetadataObjectKey");
		DataExported.Indexes.Add("FullNameLowerCase");
		
		// Preparing objects to be imported and duplicates of existing objects.
		
		ObjectsToWrite = New Array;
		FullNamesOfItemsToImport = New Map;
		KeysOfItemsToImport = New Map;
		
		For each ItemToImportProperties In ItemsToImportTable Do
			Object = ItemToImportProperties.Object;
			Ref = ItemToImportProperties.Ref;
			
			If ItemToImportProperties.Matches Then
				Continue; // There is no need to import objects that are identical to existing ones.
			EndIf;
			
			If IsCollection(Ref) Then
				ObjectsToWrite.Add(Object);
				Continue;
			EndIf;
			
			// Checking the items to be imported for duplicates.
			
			If FullNamesOfItemsToImport.Get(Lower(Object.FullName)) <> Undefined Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Ошибка загрузки идентификаторов объектов метаданных.
					           |Невозможно загрузить два элемента у которых совпадает полное имя:
					           |""%1"".'; 
					           |en = 'Metadata object ID import error.
					           |Cannot import two items with identical full names:
					           |""%1"".'; 
					           |pl = 'Wystąpił błąd podczas importowania identyfikatorów obiektów metadanych.
					           |Nie można zaimportować dwóch elementów, w których występuje pełna nazwa:
					           |""%1"".';
					           |es_ES = 'Ha ocurrido un error al importar los identificadores de los objetos de metadatos.
					           |No se puede importar dos artículos en los cuales el nombre completo coincide con:
					           |""%1"".';
					           |es_CO = 'Ha ocurrido un error al importar los identificadores de los objetos de metadatos.
					           |No se puede importar dos artículos en los cuales el nombre completo coincide con:
					           |""%1"".';
					           |tr = 'Meta veri nesneleri kimlikleri içe aktarılırken bir hata oluştu. 
					           |Tam adın eşleştiği iki %1öğe içe aktarılamıyor: "
".';
					           |it = 'Errore durante il caricamento degli identificatori degli oggetti dei metadati.
					           |Impossibile caricare due elementi il cui nome completo coincide:
					           |""%1"".';
					           |de = 'Fehler beim Laden von Metadaten-Objektbezeichnern.
					           |Es ist nicht möglich, zwei Elemente zu laden, die den gleichen vollständigen Namen haben:
					           |""%1"".'"),
					Object.FullName);
			EndIf;
			FullNamesOfItemsToImport.Insert(Lower(Object.FullName));
			
			MetadataObjectKey = Object.MetadataObjectKey.Get();
			If TypeOf(MetadataObjectKey) = Type("Type")
			   AND MetadataObjectKey <> Type("Undefined") Then
				
				If KeysOfItemsToImport.Get(MetadataObjectKey) <> Undefined Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Ошибка загрузки идентификаторов объектов метаданных.
						           |Невозможно загрузить два элемента у которых совпадает ключ объекта метаданных:
						           |""%1"".'; 
						           |en = 'Metadata object ID import error.
						           |Cannot import two items with identical metadata object keys:
						           |""%1"".'; 
						           |pl = 'Wystąpił błąd podczas importowania identyfikatorów obiektów metadanych.
						           |Nie można zaimportować dwóch pozycji, w których klucz obiektu metadanych jest identyczny
						           |""%1"".';
						           |es_ES = 'Ha ocurrido un error al importar los identificadores de los objetos de metadatos.
						           |No se puede importar dos artículos en los cuales la clave del objeto de metadatos coincide con:
						           |""%1"".';
						           |es_CO = 'Ha ocurrido un error al importar los identificadores de los objetos de metadatos.
						           |No se puede importar dos artículos en los cuales la clave del objeto de metadatos coincide con:
						           |""%1"".';
						           |tr = 'Meta veri nesneleri kimlikleri içe aktarılırken bir hata oluştu. 
						           | Meta veri nesne anahtarının eşleştiği %1 iki öğe içe aktarılamıyor: 
						           |""';
						           |it = 'Errore durante il caricamento degli identificatori degli oggetti dei metadati.
						           |Impossibile caricare due elementi la cui chiave dell''oggetto dei metadati coincide:
						           |""%1"".';
						           |de = 'Fehler beim Laden von Metadaten-Objektbezeichnern.
						           |Es ist unmöglich, zwei Elemente mit dem gleichen Metadaten-Objektschlüssel zu laden:
						           |""%1"".'"),
						String(MetadataObjectKey));
				EndIf;
				KeysOfItemsToImport.Insert(MetadataObjectKey);
				
				If ItemToImportProperties.MetadataObjectByKey <> ItemToImportProperties.MetadataObjectByFullName Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Ошибка загрузки идентификаторов объектов метаданных.
						           |Невозможно загрузить элемент у которого ключ объекта метаданных
						           |""%1"" не соответствует полному имени ""%2"".'; 
						           |en = 'Metadata object ID import error.
						           |Cannot import an item with metadata object key
						           |""%1"" that does not match its full name ""%2"".'; 
						           |pl = 'Wystąpił błąd podczas importowania identyfikatorów obiektów metadanych.
						           |Nie można zaimportować pozycji obiektu metadanych
						           |, który ""%1"" nie odpowiada pełnej nazwie ""%2"".';
						           |es_ES = 'Ha ocurrido un error al importar los identificadores de los objetos de metadatos.
						           |No se puede importar un artículo el objeto de metadatos del cual
						           |""%1"" no corresponde al nombre completo ""%2"".';
						           |es_CO = 'Ha ocurrido un error al importar los identificadores de los objetos de metadatos.
						           |No se puede importar un artículo el objeto de metadatos del cual
						           |""%1"" no corresponde al nombre completo ""%2"".';
						           |tr = 'Meta veri nesneleri kimlikleri içe aktarılırken bir hata oluştu. 
						           |""%2 "" Adının tam adı ""%1"" ile uyuşmayan öğe meta veri nesnesini içe aktarılamıyor.
						           |';
						           |it = 'Errore durante il caricamento degli identificatori degli oggetti dei metadati.
						           |Impossibile caricare un elemento la cui chiave dell''oggetto dei metadati
						           |""%1"" non coincide con il nome completo ""%2"".';
						           |de = 'Fehler beim Laden von Metadaten-Objektbezeichnern.
						           |Es ist nicht möglich, ein Element mit einem Metadaten-Objektschlüssel
						           |""%1"" zu laden, der nicht dem vollständigen Namen ""%2"" entspricht.'"),
						String(MetadataObjectKey), Object.FullName);
				EndIf;
				
				If Not Object.DeletionMark Then
					// Searching existing metadata objects for duplicates by key.
					Filter = New Structure("MetadataObjectKey", MetadataObjectKey);
					FindDuplicatesOnImportDataToSubordinateNode(DataExported, Filter, Object, Ref, ItemsToImportTable);
				EndIf;
			EndIf;
			
			If Not Object.DeletionMark Then
				// Searching existing metadata objects for duplicates by full name.
				Filter = New Structure("FullNameLowerCase", Lower(Object.FullName));
				FindDuplicatesOnImportDataToSubordinateNode(DataExported, Filter, Object, Ref, ItemsToImportTable);
			EndIf;
			
			ObjectsToWrite.Add(Object);
		EndDo;
		
		// Updating duplicates.
		Rows = DataExported.FindRows(New Structure("DuplicateUpdated", True));
		For each Properties In Rows Do
			DuplicateObject = Properties.Ref.GetObject();
			FillPropertyValues(DuplicateObject, Properties);
			DuplicateObject.MetadataObjectKey = New ValueStorage(Properties.MetadataObjectKey);
			DuplicateObject.DataExchange.Load = True;
			DuplicateObject.Write();
		EndDo;
		
		PrepareNewSubsystemsListInSubordinateNode(ObjectsToWrite);
		
		// Importing objects.
		For each Object In ObjectsToWrite Do
			Object.DataExchange.Load = True;
			Object.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// See Common.MetadataObjectIDs. 
Function MetadataObjectIDs(FullNamesOfMetadataObjects, ExcludeNonexistentItems = False, OneItem = False) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	IDsByFullNames = IDCache().IDsByFullNames;
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Result = New Map;
	FullNamesWithoutCache = New Array;
	For Each FullName In FullNamesOfMetadataObjects Do
		ID = IDsByFullNames.Get(FullName);
		If ID = Undefined Then
			FullNamesWithoutCache.Add(FullName);
		Else
			Result.Insert(FullName, ID);
		EndIf;
	EndDo;
	
	If FullNamesWithoutCache.Count() = 0 Then
		Return Result;
	EndIf;
	
	IDs = MetadataObjectIDsWithRetryAttempt(FullNamesWithoutCache,
		ExcludeNonexistentItems, OneItem);
	
	For Each KeyAndValue In IDs Do
		Result.Insert(KeyAndValue.Key, KeyAndValue.Value);
		IDsByFullNames.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns a metadata object by ID.
//
// Parameters:
//  ID - CatalogRef.MetadataObjectIDs,
//                  CatalogRef.ExtensionObjectIDs - the IDs of metadata objects in an application or 
//                    an extension.
//
//  ExceptNonexistentAndUnavailableItems - Boolean - if True, when the metadata object does not 
//                    exist or is unavailable, returns Null or Undefined instead of throwing an 
//                    exception.
//
// Returns:
//  MetadataObject - the metadata object with the specified ID.
//
//  Returns Null if ExceptNonexistentAndUnavailableItems = True. Null means there is no metadata 
//    object with this ID (the ID is invalid).
//
//  Returns Undefined if ExceptNonexistentAndUnavailableItems = True. Undefined means the ID is 
//    valid, but the session fails to get the MetadataObject.
//    For configuration extensions, that means the extension had been installed, but was not 
//    attached, or the configuration was not restarted, or attaching the extension failed.
//    For configurations, that means the new session contains the object and the current session 
//    does not contain it.
//
Function MetadataObjectByID(ID, RaiseException = False) Export
	
	IDs = New Array;
	IDs.Add(ID);
	
	MetadataObjects = MetadataObjectsByIDs(IDs, RaiseException);
	
	Return MetadataObjects.Get(ID);
	
EndFunction

// Returns metadata objects with the specified IDs.
//
// Parameters:
//  IDs - Array - of the following values:
//                     * Value - CatalogRef.MetadataObjectIDs,
//                                  CatalogRef.ExtensionObjectIDs - the IDs of metadata objects in 
//                                    an application or an extension.
//
//  ExceptNonexistentAndUnavailableItems - Boolean - if True, when the metadata object does not 
//                    exist or is unavailable, returns Null or Undefined instead of throwing an 
//                    exception.
//
// Returns:
//  Map with the following properties:
//   * Key - the ID passed to the method.
//   * Value - MetadataObject - the metadata object with this ID.
//              - Returns Null if ExceptNonexistentAndUnavailableItems = True. Null means there is 
//                  no metadata object with this ID (the ID is invalid).
//              - Returns Undefined if ExceptNonexistentAndUnavailableItems = True. Undefined means 
//                  the ID is valid, but the session fails to get the MetadataObject.
//                  For configuration extensions, that means the extension had been installed, but 
//                  was not attached, or the configuration was not restarted, or attaching the extension failed.
//                  For configurations, that means the new session contains the object and the 
//                  current session does not contain it.
//
Function MetadataObjectsByIDs(IDs, ExceptNonexistentAndUnavailableItems = False) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	DetailsOfMetadataObjectsByIDs = IDCache().DetailsOfMetadataObjectsByIDs;
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Result = New Map;
	IDsWithoutCache = New Array;
	For Each ID In IDs Do
		Details = DetailsOfMetadataObjectsByIDs.Get(ID);
		
		If Details = Undefined
		 Or Not ExceptNonexistentAndUnavailableItems
		   AND Details.Key = Undefined Then
			
			IDsWithoutCache.Add(ID);
			
		ElsIf Details.Key = Undefined Then
			Result.Insert(ID, Details.Object);
			
		ElsIf TypeOf(Details.Key) = Type("Type") Then
			Result.Insert(ID, Metadata.FindByType(Details.Key));
		Else
			Result.Insert(ID, Metadata.FindByFullName(Details.Key));
		EndIf;
	EndDo;
	
	If IDsWithoutCache.Count() = 0 Then
		Return Result;
	EndIf;
	
	MetadataObjectsByIDs = MetadataObjectsByIDsWithRetryAttempt(IDsWithoutCache,
		ExceptNonexistentAndUnavailableItems);
	
	For Each KeyAndValue In MetadataObjectsByIDs Do
		MetadataObjectDetails = KeyAndValue.Value;
		If TypeOf(MetadataObjectDetails) = Type("Structure") Then
			Result.Insert(KeyAndValue.Key, MetadataObjectDetails.Object);
			MetadataObjectDetails.Object = Undefined;
		Else
			Result.Insert(KeyAndValue.Key, KeyAndValue.Value);
			MetadataObjectDetails = New Structure("Object, Key", KeyAndValue.Value)
		EndIf;
		DetailsOfMetadataObjectsByIDs.Insert(KeyAndValue.Key, MetadataObjectDetails);
	EndDo;
	
	Return Result;
	
EndFunction

// Returns references to metadata objects found by the full name of the deleted metadata object.
// Use this function to replace or clear a reference.
//
// Parameters:
//  FullNameOfDeletedItem - String - for example "Role.ReadBasicRegulatoryData".
//
// Returns:
//  Array - with the following values:
//   * Value - CatalogRef.MetadataObjectIDs,
//                CatalogRef.ExtensionObjectIDs - found reference.
// 
Function DeletedMetadataObjectID(FullNameOfDeletedItem) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MetadataObjectIDs.Ref AS Ref,
	|	MetadataObjectIDs.FullName AS FullName
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.DeletionMark
	|
	|UNION ALL
	|
	|SELECT
	|	ExtensionObjectIDs.Ref,
	|	ExtensionObjectIDs.FullName
	|FROM
	|	Catalog.ExtensionObjectIDs AS ExtensionObjectIDs
	|WHERE
	|	ExtensionObjectIDs.DeletionMark";
	
	Selection = Query.Execute().Select();
	
	FoundRefs = New Array;
	While Selection.Next() Do
		If Not StrStartsWith(Selection.FullName, "? ") Then
			Continue;
		EndIf;
		CurrentFullNameOfDeletedItem = Mid(Selection.FullName, 3);
		BracketPosition = StrFind(CurrentFullNameOfDeletedItem, "(");
		If BracketPosition > 0 Then
			CurrentFullNameOfDeletedItem = Mid(CurrentFullNameOfDeletedItem, 1, BracketPosition - 1);
		EndIf;
		If Upper(TrimAll(CurrentFullNameOfDeletedItem)) = Upper(TrimAll(FullNameOfDeletedItem)) Then
			FoundRefs.Add(Selection.Ref);
		EndIf;
	EndDo;
	
	Return FoundRefs;
	
EndFunction

#EndRegion

#Region Private

// This procedure updates catalog data using the configuration metadata.
//
// Parameters:
//  HasChanges - Boolean (return value) - True is returned to this parameter if changes are saved. 
//                   Otherwise, not modified.
//
//  HasDeletedItems - Boolean - receives True if a catalog item was marked for deletion. Otherwise, 
//                   not modified.
//                   
//
//  CheckOnly - Boolean - make no changes, just set the HasChanges and HasDeleted flags.
//                   
//
Procedure UpdateCatalogData(HasChanges = False, HasDeletedItems = False, CheckOnly = False) Export
	
	RunDataUpdate(HasChanges, HasDeletedItems, CheckOnly);
	
EndProcedure

// Required to export all application metadata object IDs to subordinate DIB nodes if the catalog 
// was not included into the DIB before.
// Also can be used to repair the catalog data in DIB nodes.
//
Procedure RegisterTotalChangeForSubordinateDIBNodes() Export
	
	CheckForUsage();
	
	If Common.IsSubordinateDIBNode()
	 Or Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	CatalogMetadata = Metadata.Catalogs.MetadataObjectIDs;
	
	DIBNodes = New Array;
	For each ExchangePlan In Metadata.ExchangePlans Do
		If ExchangePlan.DistributedInfoBase
		   AND ExchangePlan.Content.Contains(CatalogMetadata)Then
		
			ExchangePlanManager = Common.ObjectManagerByFullName(ExchangePlan.FullName());
			Selection = ExchangePlanManager.Select();
			While Selection.Next() Do
				If Selection.Ref <> ExchangePlanManager.ThisNode() Then
					DIBNodes.Add(Selection.Ref);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	If DIBNodes.Count() > 0 Then
		ExchangePlans.RecordChanges(DIBNodes, CatalogMetadata);
	EndIf;
	
EndProcedure

// This procedure updates catalog data using the configuration metadata.
//
// Parameters:
//  HasChanges - Boolean (return value) - True is returned to this parameter if changes are saved. 
//                  Otherwise, not modified.
//
//  HasDeletedItems - Boolean - receives True if a catalog item was marked for deletion. Otherwise, 
//                  not modified.
//                  
//
//  CheckOnly - Boolean - make no changes, just set the HasChanges, HasDeleted, HasCriticalChanges, 
//                   and ListOfCriticalChanges flags.
//
//  HasCriticalChanges - (return value) receives True if critical changes are found. Otherwise not 
//                  modified.
//                    Critical changes (only for items without deletion mark) include:
//                    - FullName attribute change,
//                    - adding a new catalog item.
//                  Generally, the exclusive mode is required for any critical changes.
//
//  ListOfCriticalChanges - String - contains full names of metadata objects that were added or must 
//                  be added, and also whose names were changed or must be changed.
//                  
//
Procedure RunDataUpdate(HasChanges, HasDeletedItems, CheckOnly,
			HasCriticalChanges = False, ListOfCriticalChanges = "", ExtensionsObjects = False) Export
	
	If ExtensionsObjects
	   AND ValueIsFilled(SessionParameters.AttachedExtensions)
	   AND Not Common.SeparatedDataUsageAvailable() Then
		
		ErrorText =
			NStr("ru = 'Невозможно обновить идентификаторы объектов расширений
			           |в сеансе неразделенного пользователя, так как
			           |расширения для разделенных пользователей не подключены.'; 
			           |en = 'Cannot update extension object IDs
			           |in a shared user session because
			           |extensions for separated users are not attached.'; 
			           |pl = 'Nie można zaktualizować identyfikatorów
			           |obiektów rozszerzeń we współużytkowanej sesji użytkownika, ponieważ
			           |rozszerzenia dla oddzielnych użytkowników nie są dołączone.';
			           |es_ES = 'Es imposible actualizar los identificadores de los objetos de las extensiones 
			           |en la sesión del usuario no distribuido porque
			           | las extensiones para los usuarios distribuidos no están conectadas.';
			           |es_CO = 'Es imposible actualizar los identificadores de los objetos de las extensiones 
			           |en la sesión del usuario no distribuido porque
			           | las extensiones para los usuarios distribuidos no están conectadas.';
			           |tr = 'Paylaşılan kullanıcılar için uzantılar bağlı olmadığından, 
			           |paylaşılan bir kullanıcı oturumunda uzantı nesne kimlikleri 
			           |güncelleştirilemiyor.';
			           |it = 'Impossibile aggiornare gli ID degli oggetti di estensione
			           |in una sessione utenti condivisa poiché
			           |le estensioni per utenti separati non sono collegate.';
			           |de = 'Es ist nicht möglich, die Identifikatoren von Erweiterungsobjekten
			           |in einer ungeteilten Benutzersitzung zu aktualisieren, da
			           |Erweiterungen für geteilte Benutzer nicht verbunden sind.'");
		
		RaiseByError(True,
			ExtensionObjectsIDsUnvailableInSharedModeErrorDescription());
	EndIf;
	
	CheckForUsage(ExtensionsObjects);
	
	SetPrivilegedMode(True);
	
	HasCurrentChanges = False;
	If Not ExtensionsObjects Then
		ReplaceSubordinateNodeDuplicatesFoundOnImport(CheckOnly, HasCurrentChanges);
	EndIf;
	
	UpdateData(HasCurrentChanges, HasDeletedItems, CheckOnly,
		HasCriticalChanges, ListOfCriticalChanges, ExtensionsObjects);
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
	If Not ExtensionsObjects Then
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.Core.MetadataObjectIDs", True);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Implementation of procedures declared in other modules.

// See Common.MetadataObjectID. 
Function MetadataObjectID(MetadataObjectDetails) Export
	
	MetadataObjectDetailsType = TypeOf(MetadataObjectDetails);
	If MetadataObjectDetailsType = Type("Type") Then
		
		MetadataObject = Metadata.FindByType(MetadataObjectDetails);
		If MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при выполнении функции Common.MetadataObjectID().
				           |
				           |Объект метаданных не найден по типу:
				           |""%1"".'; 
				           |en = 'Common.MetadataObjectID() function error.
				           |
				           |Cannot find metadata object by type:
				           |""%1"".'; 
				           |pl = 'Wystąpił błąd podczas wykonywania funkcji CommonUse.MetadataObjectID().
				           |
				           |Nie znaleziono obiektu metadanych według typu:
				           |""%1"".';
				           |es_ES = 'Ha ocurrido un error durante la ejecución de la función CommonUse.MetadataObjectID().
				           |
				           |Objeto de metadatos no encontrado por el tipo:
				           |""%1"".';
				           |es_CO = 'Ha ocurrido un error durante la ejecución de la función CommonUse.MetadataObjectID().
				           |
				           |Objeto de metadatos no encontrado por el tipo:
				           |""%1"".';
				           |tr = 'Common.MetadataObjectID() işlevinin yürütülmesi sırasında bir hata oluştu. 
				           |
				           |Meta veri nesnesi türüne göre bulunamadı:
				           |""%1"".';
				           |it = 'Errore funzione Common.MetadataObjectID().
				           |
				           |Impossibile trovare oggetto di metadati per tipo:
				           |""%1"".';
				           |de = 'Fehler bei der Ausführung der Funktion Common.MetadataObjectID().
				           |
				           |Metadaten-Objekt wird nicht nach Typ:
				           |""%1"" gefunden.'"),
				MetadataObjectDetails);
		Else
			FullMetadataObjectName = MetadataObject.FullName();
		EndIf;
		
	ElsIf MetadataObjectDetailsType = Type("String") Then
		FullMetadataObjectName = MetadataObjectDetails;
		
	ElsIf MetadataObjectDetailsType = Type("MetadataObject") Then
		FullMetadataObjectName = MetadataObjectDetails.FullName();
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка при выполнении функции Common.MetadataObjectID().
			           |
			           |Указан недопустимый тип параметра MetadataObjectDetails:
			           |""%1"".'; 
			           |en = 'Common.MetadataObjectID() function error.
			           |
			           |Invalid MetadataObjectDetails parameter type:
			           |""%1"".'; 
			           |pl = 'Błąd funkcji Common.MetadataObjectID().
			           |
			           |Nieprawidłowy typ parametru MetadataObjectDetails:
			           |""%1"".';
			           |es_ES = 'Error de la función Common.MetadataObjectID (). 
			           |
			           |Tipo de parámetro MetadataObjectDetails no válido: 
			           |""%1"".';
			           |es_CO = 'Error de la función Common.MetadataObjectID (). 
			           |
			           |Tipo de parámetro MetadataObjectDetails no válido: 
			           |""%1"".';
			           |tr = 'Common.MetadataObjectID() işlevi yürütülürken bir hata oluştu. 
			           |
			           |MetadataObjectDetails parametresinin türü kabul edilemez: 
			           |""%1"".';
			           |it = 'Errore funzione Common.MetadataObjectID().
			           |
			           |Tipo parametro MetadataObjectDetails non valido:
			           |""%1"".';
			           |de = 'Fehler bei der Ausführung der Funktion Common.MetadataObjectID().
			           |
			           |Der ungültige Parametertyp wird angegeben Beschreibung des Metadatenobjekts:
			           |""%1"".'"),
			MetadataObjectDetailsType);
	EndIf;
	
	Array = New Array;
	Array.Add(FullMetadataObjectName);
	
	Return MetadataObjectIDs(Array, , True).Get(FullMetadataObjectName);
	
EndFunction

// See Common.AddRenaming. 
Procedure AddRenaming(Total, IBVersion, PreviousFullName, NewFullName, LibraryID = "") Export
	
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck();
	
	PreviousCollectionName = Upper(CollectionName(PreviousFullName));
	NewCollectionName  = Upper(CollectionName(NewFullName));
	
	ErrorTitle =
		NStr("ru = 'Ошибка в процедуре OnAddMetadataObjectRenaming общего модуля CommonOverridable.'; en = 'CommonOverridable.OnAddMetadataObjectRenaming procedure error.'; pl = 'Wystąpił błąd w procedurze CommonOverridable.OnAddMetadataObjectRenaming.';es_ES = 'Ha ocurrido un error en el procedimiento OnAddMetadataObjectsRenaming del módulo común CommonUseOverridable.';es_CO = 'Ha ocurrido un error en el procedimiento OnAddMetadataObjectsRenaming del módulo común CommonUseOverridable.';tr = 'CommonOverridable ortak modülünün OnAddMetadataObjectRenaming prosedüründe bir hata oluştu.';it = 'CommonOverridable.Errore procedura OnAddMetadataObjectRenaming.';de = 'In der Prozedur CommonOverridable.OnAddMetadataObjectRenaming ist ein Fehler aufgetreten.'");
	
	If PreviousCollectionName <> NewCollectionName Then
		Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не совпадают имена типов переименованного объекта метаданных.
			           |Прежний тип: ""%1"",
			           |новый тип: ""%2"".'; 
			           |en = 'Type mismatch in the renamed metadata object.
			           |Previous type: ""%1"",
			           |new type: ""%2"".'; 
			           |pl = 'Nazwy typów obiektu metadanych o zmienionej nazwie nie są zgodne.
			           |Poprzedni typ: ""%1"",
			           |nowy typ: ""%2"".';
			           |es_ES = 'Nombres de los tipos del objeto de metadatos renombrado no coinciden.
			           |Previo tipo: ""%1"",
			           |nuevo tipo: ""%2"".';
			           |es_CO = 'Nombres de los tipos del objeto de metadatos renombrado no coinciden.
			           |Previo tipo: ""%1"",
			           |nuevo tipo: ""%2"".';
			           |tr = 'Yeniden adlandırılmış meta veri nesnesinin tür adları eşleşmiyor. 
			           |Önceki tip: %1
			           | yeni tip:""%2"".';
			           |it = 'I nomi dei tipi dell''oggetto dei metadati rinominato non coincidono.
			           |Tipo precedente: ""%1"", 
			           |nuovo tipo: ""%2"".';
			           |de = 'Die Typ-Namen des umbenannten Metadatenobjekts stimmen nicht überein.
			           |Früherer Typ: ""%1"",
			           |neuer Typ: ""%2"".'"),
			PreviousFullName,
			NewFullName);
	EndIf;
	
	If Total.CollectionsWithoutKey[PreviousCollectionName] = Undefined Then
		
		AllowedTypesList = "";
		For each KeyAndValue In Total.CollectionsWithoutKey Do
			AllowedTypesList = AllowedTypesList + KeyAndValue.Value + "," + Chars.LF;
		EndDo;
		AllowedTypesList = TrimR(AllowedTypesList);
		AllowedTypesList = ?(ValueIsFilled(AllowedTypesList),
			Left(AllowedTypesList, StrLen(AllowedTypesList) - 1), "");
		
		Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для типа объекта метаданных ""%1"" не требуется описывать переименование,
			           |так как сведения об объектах метаданных этого типа обновляются автоматически.
			           |
			           |Описывать переименования требуется только для следующих типов:
			           |%2.'; 
			           |en = 'Describing the renaming of ""%1"" metadata object is not required,
			           |as the details of metadata objects of this type are updated automatically.
			           |
			           |It is required only for the following types:
			           |%2.'; 
			           |pl = 'Nie jest wymagane opisywanie zmiany nazwy obiektu dla
			           | obiektu metadanych typu ""%1"", ponieważ informacje o obiekcie metadanych tego typu są aktualizowane automatycznie.
			           |
			           |Wymagane jest opisanie zmian nazw tylko dla następujących typów:
			           |%2.';
			           |es_ES = 'No se requiere describir el cambio de nombre para el tipo del objeto de metadatos ""%1"",
			           |porque la información sobre el objeto de metadatos de este tipo está actualizado automáticamente.
			           |
			           |Se requiere describir los cambios de nombre solo para los siguientes tipos:
			           |%2.';
			           |es_CO = 'No se requiere describir el cambio de nombre para el tipo del objeto de metadatos ""%1"",
			           |porque la información sobre el objeto de metadatos de este tipo está actualizado automáticamente.
			           |
			           |Se requiere describir los cambios de nombre solo para los siguientes tipos:
			           |%2.';
			           |tr = 'Bu tür meta veri nesnesi hakkında bilgi otomatik olarak güncellendiği için, 
			           |meta veri nesne türü %1 için yeniden adlandırmanın tanımlanması gerekmez
			           |
			           |Yalnızca aşağıdaki türlerde yeniden adlandırmaları tanımlamak gerekir:
			           |%2.';
			           |it = 'Per il tipo dell''oggetto dei metadati ""%1"" non è necessario descrivere la ridenominazione
			           |poiché le informazioni sugli oggetti dei metadati di questo tipo vengono aggiornate automaticamente.
			           |
			           |Descrivere la ridenominazione è necessario solo per i seguenti tipi:
			           |%2.';
			           |de = 'Für den Metadaten-Objekttyp ""%1"" ist es nicht notwendig, die Umbenennung zu beschreiben,
			           |da die Details zu Metadaten-Objekten dieses Typs automatisch aktualisiert werden.
			           |
			           |Für die Umbenennung müssen nur die folgenden Typen beschrieben werden:
			           |%2.'"),
			PreviousFullName,
			AllowedTypesList);
	EndIf;
	
	If Not ValueIsFilled(LibraryID) Then
		LibraryID = Metadata.Name;
	EndIf;
	
	LibraryOrder = Total.LibrariesOrder[LibraryID];
	If LibraryOrder = Undefined Then
		LibraryOrder = Total.LibrariesOrder.Count();
		Total.LibrariesOrder.Insert(LibraryID, LibraryOrder);
	EndIf;
	
	LibraryVersion = Total.LibrariesVersions[LibraryID];
	If LibraryVersion = Undefined Then
		LibraryVersion = InfobaseUpdateInternal.IBVersion(LibraryID);
		Total.LibrariesVersions.Insert(LibraryID, LibraryVersion);
	EndIf;
	
	If LibraryVersion = "0.0.0.0" Then
		// No renaming is required during the initial filling.
		Return;
	EndIf;
	
	Result = CommonClientServer.CompareVersions(IBVersion, LibraryVersion);
	If Result > 0 Then
		VersionParts = StrSplit(IBVersion, ".");
		
		RenamingDetails = Total.Table.Add();
		RenamingDetails.LibraryOrder = LibraryOrder;
		RenamingDetails.VersionPart1      = Number(VersionParts[0]);
		RenamingDetails.VersionPart2      = Number(VersionParts[1]);
		RenamingDetails.VersionPart3      = Number(VersionParts[2]);
		RenamingDetails.VersionPart4      = Number(VersionParts[3]);
		RenamingDetails.PreviousFullName   = PreviousFullName;
		RenamingDetails.NewFullName    = NewFullName;
		RenamingDetails.AdditionOrder = Total.Table.IndexOf(RenamingDetails);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional procedures and functions intended to be called from other modules.

// For internal use only.
// FullName for the object must be specified and valid.
//
Procedure UpdateIDProperties(Object) Export
	
	ExtensionsObjects = IsExtensionObject(Object);
	
	If ExtensionsObjects
	   AND Catalogs.ExtensionObjectIDs.ExtensionObjectDisabled(Object.Ref) Then
		Return;
	EndIf;
	
	FullName = Object.FullName;
	
	// Restoring earlier values.
	If ValueIsFilled(Object.Ref) Then
		PreviousValues = Common.ObjectAttributesValues(
			Object.Ref,
			"Description,
			|CollectionOrder,
			|Name,
			|FullName,
			|Synonym,
			|FullSynonym,
			|NoData,
			|EmptyRefValue,
			|MetadataObjectKey");
		FillPropertyValues(Object, PreviousValues);
	EndIf;
	
	MetadataObject = MetadataFindByFullName(FullName);
	
	If MetadataObject = Undefined Then
		Object.DeletionMark       = True;
		Object.Parent              = EmptyCatalogRef(ExtensionsObjects);
		Object.Description          = InsertQuestionMark(Object.Description);
		Object.Name                   = InsertQuestionMark(Object.Name);
		Object.Synonym               = InsertQuestionMark(Object.Synonym);
		Object.FullName             = InsertQuestionMark(Object.FullName);
		Object.FullSynonym         = InsertQuestionMark(Object.FullSynonym);
		Object.EmptyRefValue  = Undefined;
		
		If ExtensionsObjects Then
			Object.ExtensionName      = InsertQuestionMark(Object.ExtensionName);
			Object.ExtensionHashsum = InsertQuestionMark(Object.ExtensionHashsum);
		EndIf;
		
		If TypeOf(Object) <> Type("FormDataStructure") Then
			Object.MetadataObjectKey = Undefined;
		EndIf;
	Else
		Object.DeletionMark = False;
		
		FullName = MetadataObject.FullName();
		PointPosition = StrFind(FullName, ".");
		BaseTypeName = Left(FullName, PointPosition -1);
		
		CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
		Filter = New Structure("SingularName", BaseTypeName);
		Rows = CollectionsProperties.FindRows(Filter);
		
		MetadataObjectProperties = MetadataObjectProperties(IsExtensionObject(Object),
			CollectionsProperties.Copy(Rows));
		
		ObjectProperties = MetadataObjectProperties.Find(FullName, "FullName");
		
		FillPropertyValues(Object, ObjectProperties);
		
		If TypeOf(Object) <> Type("FormDataStructure") Then
			MetadataObjectKey = Object.MetadataObjectKey.Get();
			If MetadataObjectKey = Undefined
			 OR ObjectProperties.NoMetadataObjectKey
			     AND MetadataObjectKey <> Type("Undefined") Then
				
				Object.MetadataObjectKey = New ValueStorage(MetadataObjectKey(ObjectProperties.FullName));
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// For internal use only.
Function RenamingTableForCurrentVersion() Export
	
	RenamingTable = New ValueTable;
	RenamingTable.Columns.Add("LibraryOrder", New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart1",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart2",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart3",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart4",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("AdditionOrder", New TypeDescription("Number"));
	RenamingTable.Columns.Add("PreviousFullName",   New TypeDescription("String"));
	RenamingTable.Columns.Add("NewFullName",    New TypeDescription("String"));
	
	CollectionsWithoutKey = New Map;
	
	Filter = New Structure("NoMetadataObjectKey", True);
	
	CollectionsWithoutMetadataObjectKey =
		StandardSubsystemsCached.MetadataObjectCollectionProperties().FindRows(Filter);
	
	For each Row In CollectionsWithoutMetadataObjectKey Do
		CollectionsWithoutKey.Insert(Upper(Row.SingularName), Row.SingularName);
	EndDo;
	
	Total = New Structure;
	Total.Insert("Table", RenamingTable);
	Total.Insert("CollectionsWithoutKey", CollectionsWithoutKey);
	Total.Insert("LibrariesVersions",  New Map);
	Total.Insert("LibrariesOrder", New Map);
	
	CommonOverridable.OnAddMetadataObjectsRenaming(Total);
	SSLSubsystemsIntegration.OnAddMetadataObjectsRenaming(Total);
	
	RenamingTable.Sort(
		"LibraryOrder ASC,
		|VersionPart1 ASC,
		|VersionPart2 ASC,
		|VersionPart3 ASC,
		|VersionPart4 ASC,
		|AdditionOrder ASC");
	
	Return RenamingTable;
	
EndFunction

// For internal use only.
Function MetadataObjectCollectionProperties(ExtensionsObjects = False) Export
	
	MetadataObjectCollectionProperties = New ValueTable;
	MetadataObjectCollectionProperties.Columns.Add("Name",                       New TypeDescription("String",, New StringQualifiers(50)));
	MetadataObjectCollectionProperties.Columns.Add("SingularName",               New TypeDescription("String",, New StringQualifiers(50)));
	MetadataObjectCollectionProperties.Columns.Add("Synonym",                   New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectCollectionProperties.Columns.Add("SingularSynonym",           New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectCollectionProperties.Columns.Add("CollectionOrder",          New TypeDescription("Number"));
	MetadataObjectCollectionProperties.Columns.Add("NoData",                 New TypeDescription("Boolean"));
	MetadataObjectCollectionProperties.Columns.Add("NoMetadataObjectKey", New TypeDescription("Boolean"));
	MetadataObjectCollectionProperties.Columns.Add("ID",             New TypeDescription("UUID"));
	MetadataObjectCollectionProperties.Columns.Add("ExtensionsObjects",         New TypeDescription("Boolean"));
	
	// Constants
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("627a6fb8-872a-11e3-bb87-005056c00008");
	Row.Name             = "Constants";
	Row.Synonym         = NStr("ru = 'Константы'; en = 'Constants'; pl = 'Stałe';es_ES = 'Constantes';es_CO = 'Constantes';tr = 'Sabitler';it = 'Costanti';de = 'Konstanten'");
	Row.SingularName     = "Constant";
	Row.SingularSynonym = NStr("ru = 'Константа'; en = 'Constant'; pl = 'Stała';es_ES = 'Constante';es_CO = 'Constante';tr = 'Sabit';it = 'Costante';de = 'Konstante'");
	
	// Subsystems
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("cdf5ac50-08e8-46af-9a80-4e63fd4a88ff");
	Row.Name             = "Subsystems";
	Row.Synonym         = NStr("ru = 'Подсистемы'; en = 'Subsystems'; pl = 'Podsystemy';es_ES = 'Subsistemas';es_CO = 'Subsistemas';tr = 'Alt sistemler';it = 'Sottosistemi';de = 'Untersysteme'");
	Row.SingularName     = "Subsystem";
	Row.SingularSynonym = NStr("ru = 'Подсистема'; en = 'Subsystem'; pl = 'Podsystem';es_ES = 'Subsistema';es_CO = 'Subsistema';tr = 'Alt sistem';it = 'Sottosistema';de = 'Untersystem'");
	Row.NoData       = True;
	Row.NoMetadataObjectKey = True;
	Row.ExtensionsObjects = True;
	
	// Roles
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("115c4f55-9c20-4e86-a6d0-d0167ec053a1");
	Row.Name             = "Roles";
	Row.Synonym         = NStr("ru = 'Роли'; en = 'Roles'; pl = 'Role';es_ES = 'Papeles';es_CO = 'Papeles';tr = 'Roller';it = 'Ruoli';de = 'Rollen'");
	Row.SingularName     = "Role";
	Row.SingularSynonym = NStr("ru = 'Роль'; en = 'Role'; pl = 'Rola';es_ES = 'Rol';es_CO = 'Rol';tr = 'Rol';it = 'Ruolo';de = 'Rolle'");
	Row.NoData       = True;
	Row.NoMetadataObjectKey = True;
	Row.ExtensionsObjects = True;
	
	// ExchangePlans
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("269651e0-4b06-4f9d-aaab-a8d2b6bc6077");
	Row.Name             = "ExchangePlans";
	Row.Synonym         = NStr("ru = 'Планы обмена'; en = 'Exchange plans'; pl = 'Plany wymiany';es_ES = 'Planos de intercambio';es_CO = 'Planos de intercambio';tr = 'Değiştirme planları';it = 'Piani di scambio';de = 'Austauschpläne'");
	Row.SingularName     = "ExchangePlan";
	Row.SingularSynonym = NStr("ru = 'План обмена'; en = 'Exchange plan'; pl = 'Plan wymiany';es_ES = 'Plan de intercambio';es_CO = 'Plan de intercambio';tr = 'Değiştirme planı';it = 'Piano di scambio';de = 'Exchange-Plan'");
	Row.ExtensionsObjects = True;
	
	// Catalogs
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("ede89702-30f5-4a2a-8e81-c3a823b7e161");
	Row.Name             = "Catalogs";
	Row.Synonym         = NStr("ru = 'Справочники'; en = 'Catalogs'; pl = 'Katalogi';es_ES = 'Catálogos';es_CO = 'Catálogos';tr = 'Ana kayıtlar';it = 'Anagrafiche';de = 'Kataloge'");
	Row.SingularName     = "Catalog";
	Row.SingularSynonym = NStr("ru = 'Справочник'; en = 'Catalog'; pl = 'Katalog';es_ES = 'Catálogo';es_CO = 'Catálogo';tr = 'Katalog';it = 'Anagrafica';de = 'Katalog'");
	Row.ExtensionsObjects = True;
	
	// Documents
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("96c6ab56-0375-40d5-99a2-b83efa3dac8b");
	Row.Name             = "Documents";
	Row.Synonym         = NStr("ru = 'Документы'; en = 'Documents'; pl = 'Dokumenty';es_ES = 'Documentos';es_CO = 'Documentos';tr = 'Belgeler';it = 'Documenti';de = 'Dokumente'");
	Row.SingularName     = "Document";
	Row.SingularSynonym = NStr("ru = 'Документ'; en = 'Document'; pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'");
	Row.ExtensionsObjects = True;
	
	// DocumentJournals
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("07938234-e29b-4cff-961a-9af07a4c6185");
	Row.Name             = "DocumentJournals";
	Row.Synonym         = NStr("ru = 'Журналы документов'; en = 'Document journals'; pl = 'Dzienniki wydarzeń dokumentu';es_ES = 'Registros del documento';es_CO = 'Registros del documento';tr = 'Belge günlükleri';it = 'Registro documenti';de = 'Dokumentprotokolle'");
	Row.SingularName     = "DocumentJournal";
	Row.SingularSynonym = NStr("ru = 'Журнал документов'; en = 'Document journal'; pl = 'Dziennik dokumentu';es_ES = 'Diario de documentos';es_CO = 'Diario de documentos';tr = 'Belge günlüğü';it = 'Registro documenti';de = 'Dokument Journal'");
	Row.NoData       = True;
	
	// Reports
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("706cf832-0ae5-45b5-8a4a-1f251d054f3b");
	Row.Name             = "Reports";
	Row.Synonym         = NStr("ru = 'Отчеты'; en = 'Reports'; pl = 'Sprawozdania';es_ES = 'Informes';es_CO = 'Informes';tr = 'Raporlar';it = 'Reports';de = 'Berichte'");
	Row.SingularName     = "Report";
	Row.SingularSynonym = NStr("ru = 'Отчет'; en = 'Report'; pl = 'Raport';es_ES = 'Informe';es_CO = 'Informe';tr = 'Rapor';it = 'Report';de = 'Bericht'");
	Row.NoData       = True;
	Row.ExtensionsObjects = True;
	
	// Data processors
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("ae480426-487e-40b2-98ba-d207777449f3");
	Row.Name             = "DataProcessors";
	Row.Synonym         = NStr("ru = 'Обработки'; en = 'Data processors'; pl = 'Opracowania';es_ES = 'Procesadores de datos';es_CO = 'Procesadores de datos';tr = 'Veri işlemcileri';it = 'Elaboratori di dati';de = 'Datenverarbeiter'");
	Row.SingularName     = "DataProcessor";
	Row.SingularSynonym = NStr("ru = 'Обработка'; en = 'Data processor'; pl = 'Procesor danych';es_ES = 'Procesador de datos';es_CO = 'Procesador de datos';tr = 'Veri işlemcisi';it = 'Processore dati';de = 'Daten Prozessor'");
	Row.NoData       = True;
	Row.ExtensionsObjects = True;
	
	// ChartsOfCharacteristicTypes
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("8b5649b9-cdd1-4698-9aac-12ba146835c4");
	Row.Name             = "ChartsOfCharacteristicTypes";
	Row.Synonym         = NStr("ru = 'Планы видов характеристик'; en = 'Charts of characteristic types'; pl = 'Plany rodzajów charakterystyk';es_ES = 'Diagramas de los tipos de características';es_CO = 'Diagramas de los tipos de características';tr = 'Özellik türü listeleri';it = 'Grafici di tipi caratteristiche';de = 'Diagramme von charakteristischen Typen'");
	Row.SingularName     = "ChartOfCharacteristicTypes";
	Row.SingularSynonym = NStr("ru = 'План видов характеристик'; en = 'Chart of characteristic types'; pl = 'Plan rodzajów charakterystyk';es_ES = 'Diagrama de los tipos de características';es_CO = 'Diagrama de los tipos de características';tr = 'Özellik türü listesi';it = 'Grafico dei tipi caratteristici';de = 'Diagramm von charakteristischen Typen'");
	Row.ExtensionsObjects = True;
	
	// ChartsOfAccounts
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("4295af27-543f-4373-bcfc-c0ace9b7620c");
	Row.Name             = "ChartsOfAccounts";
	Row.Synonym         = NStr("ru = 'Планы счетов'; en = 'Charts of accounts'; pl = 'Plany kont';es_ES = 'Diagramas de las cuentas';es_CO = 'Diagramas de las cuentas';tr = 'Hesap planları';it = 'Piani dei conti';de = 'Kontenpläne'");
	Row.SingularName     = "ChartOfAccounts";
	Row.SingularSynonym = NStr("ru = 'План счетов'; en = 'Chart of accounts'; pl = 'Plan kont';es_ES = 'Diagrama primario de las cuentas';es_CO = 'Diagrama primario de las cuentas';tr = 'Hesap planı';it = 'Piano dei conti';de = 'Kontenplan'");
	Row.ExtensionsObjects = True;
	
	// ChartsOfCalculationTypes
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("fca3e7e1-1bf1-49c8-9921-aafb4e787c75");
	Row.Name             = "ChartsOfCalculationTypes";
	Row.Synonym         = NStr("ru = 'Планы видов расчета'; en = 'Charts of calculation types'; pl = 'Plany typów obliczeń';es_ES = 'Diagramas de los tipos de cálculos';es_CO = 'Diagramas de los tipos de cálculos';tr = 'Hesaplama türleri çizelgeleri';it = 'Grafici di tipi di calcolo';de = 'Diagramme der Berechnungstypen'");
	Row.SingularName     = "ChartOfCalculationTypes";
	Row.SingularSynonym = NStr("ru = 'План видов расчета'; en = 'Chart of calculation types'; pl = 'Plan typów obliczeń';es_ES = 'Diagrama de los tipos de cálculos';es_CO = 'Diagrama de los tipos de cálculos';tr = 'Hesaplama türleri çizelgesi';it = 'Piano dei tipi di calcolo';de = 'Diagramm der Berechnungstypen'");
	Row.ExtensionsObjects = True;
	
	// InformationRegisters
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("d7ecc1e9-c068-44dd-83c2-1323ec52dbbb");
	Row.Name             = "InformationRegisters";
	Row.Synonym         = NStr("ru = 'Регистры сведений'; en = 'Information registers'; pl = 'Rejestry informacji';es_ES = 'Registros de información';es_CO = 'Registros de información';tr = 'Bilgi kayıtları';it = 'Registri informazioni';de = 'Informationsregister'");
	Row.SingularName     = "InformationRegister";
	Row.SingularSynonym = NStr("ru = 'Регистр сведений'; en = 'Information register'; pl = 'Rejestr informacji';es_ES = 'Registro de información';es_CO = 'Registro de información';tr = 'Bilgi kaydı';it = 'Registro informazioni';de = 'Informationsregister'");
	Row.ExtensionsObjects = True;
	
	// AccumulationRegisters
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("74083488-b01e-4441-84a6-c386ce88cdb5");
	Row.Name             = "AccumulationRegisters";
	Row.Synonym         = NStr("ru = 'Регистры накопления'; en = 'Accumulation registers'; pl = 'Rejestry akumulacji';es_ES = 'Registros de acumulación';es_CO = 'Registros de acumulación';tr = 'Birikim kayıtları';it = 'Registri di accumulo';de = 'Akkumulationsregister'");
	Row.SingularName     = "AccumulationRegister";
	Row.SingularSynonym = NStr("ru = 'Регистр накопления'; en = 'Accumulation register'; pl = 'Rejestr akumulacji';es_ES = 'Registro de acumulación';es_CO = 'Registro de acumulación';tr = 'Birikim kaydı';it = 'Registro di accumulo';de = 'Akkumulationsregister'");
	Row.ExtensionsObjects = True;
	
	// AccountingRegisters
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("9a0d75ff-0eda-454e-b2b7-d2412ffdff18");
	Row.Name             = "AccountingRegisters";
	Row.Synonym         = NStr("ru = 'Регистры бухгалтерии'; en = 'Accounting registers'; pl = 'Rejestry księgowe';es_ES = 'Registros de contabilidad';es_CO = 'Registros de contabilidad';tr = 'Muhasebe kayıtları';it = 'Registri contabili';de = 'Buchhaltungsregister'");
	Row.SingularName     = "AccountingRegister";
	Row.SingularSynonym = NStr("ru = 'Регистр бухгалтерии'; en = 'Accounting register'; pl = 'Rejestr księgowy';es_ES = 'Registro de contabilidad';es_CO = 'Registro de contabilidad';tr = 'Muhasebe kaydı';it = 'Registro contabile';de = 'Buchhaltungsregister'");
	Row.ExtensionsObjects = True;
	
	// CalculationRegisters
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("f330686a-0acf-4e26-9cda-108f1404687d");
	Row.Name             = "CalculationRegisters";
	Row.Synonym         = NStr("ru = 'Регистры расчета'; en = 'Calculation registers'; pl = 'Rejestry obliczeń';es_ES = 'Registros de cálculos';es_CO = 'Registros de cálculos';tr = 'Hesaplama kayıtları';it = 'Registri di calcolo';de = 'Berechnungsregister'");
	Row.SingularName     = "CalculationRegister";
	Row.SingularSynonym = NStr("ru = 'Регистр расчета'; en = 'Calculation register'; pl = 'Rejestr obliczeń';es_ES = 'Registro de cálculos';es_CO = 'Registro de cálculos';tr = 'Hesaplama kaydı';it = 'Registro di calcolo';de = 'Berechnungsregister'");
	Row.ExtensionsObjects = True;
	
	// BusinessProcesses
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("a8cdd0e0-c27f-4bf0-9718-10ec054dc468");
	Row.Name             = "BusinessProcesses";
	Row.Synonym         = NStr("ru = 'Бизнес-процессы'; en = 'Business processes'; pl = 'Procesy biznesowe';es_ES = 'Procesos de negocio';es_CO = 'Procesos de negocio';tr = 'İş süreçleri';it = 'Processi di business';de = 'Geschäftsprozesse'");
	Row.SingularName     = "BusinessProcess";
	Row.SingularSynonym = NStr("ru = 'Бизнес-процесс'; en = 'Business process'; pl = 'Proces biznesowy';es_ES = 'Proceso de negocio';es_CO = 'Proceso de negocio';tr = 'İş süreci';it = 'Processo di business';de = 'Geschäftsprozess'");
	
	// Tasks
	Row = MetadataObjectCollectionProperties.Add();
	Row.ID   = New UUID("8d9153ad-7cea-4e25-9542-a557ee59fd16");
	Row.Name             = "Tasks";
	Row.Synonym         = NStr("ru = 'Задач'; en = 'Tasks'; pl = 'Zadania';es_ES = 'Tareas';es_CO = 'Tareas';tr = 'Görevler';it = 'Compiti';de = 'Aufgaben'");
	Row.SingularName     = "Task";
	Row.SingularSynonym = NStr("ru = 'Задача'; en = 'Task'; pl = 'Zadanie';es_ES = 'Tarea';es_CO = 'Tarea';tr = 'Görev';it = 'Compito';de = 'Aufgabe'");
	
	For each Row In MetadataObjectCollectionProperties Do
		Row.CollectionOrder = MetadataObjectCollectionProperties.IndexOf(Row);
	EndDo;
	
	If ExtensionsObjects Then
		MetadataObjectCollectionProperties = MetadataObjectCollectionProperties.Copy(
			New Structure("ExtensionsObjects", True));
	EndIf;
	
	MetadataObjectCollectionProperties.Indexes.Add("ID");
	
	Return MetadataObjectCollectionProperties;
	
EndFunction

// Prevents illegal modification of the metadata object IDs.
// Processes duplicate objects in a subordinate node of the distributed infobase.
//
Procedure BeforeWriteObject(Object) Export
	
	ExtensionsObjects = IsExtensionObject(Object);
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck(, ExtensionsObjects);
	
	// Disabling the object registration mechanism.
	Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	
	// Registering the object in all DIB nodes.
	For Each ExchangePlan In StandardSubsystemsCached.DIBExchangePlans() Do
		StandardSubsystemsServer.RecordObjectChangesInAllNodes(Object, ExchangePlan, False);
	EndDo;
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	CheckObjectBeforeWrite(Object);
	
EndProcedure

// Prevents the metadata object IDs without deletion mark from being deleted.
Procedure BeforeDeleteObject(Object) Export
	
	ExtensionsObjects = IsExtensionObject(Object);
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck(, ExtensionsObjects);
	
	// Disabling the object registration mechanism.
	// ID references are deleted independently in each node using deletion marks and marked object 
	// deletion.
	Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Object.DeletionMark Then
		RaiseByError(ExtensionsObjects,
			NStr("ru = 'Удаление идентификаторов объектов, у которых значение
			           |реквизита ""Пометка удаления"" установлено False, недопустимо.'; 
			           |en = 'Cannot delete IDs of objects that have
			           |the ""Deletion mark"" attribute set to False.'; 
			           |pl = 'Nie można usunąć identyfikatorów obiektów, które mają atrybut
			           |""Znacznik usunięcia"" ustawiony na False.';
			           |es_ES = 'Identificador del objeto de metadatos del cual el valor
			           |del atributo ""Marca para borrar"" está establecida False no es válido.';
			           |es_CO = 'Identificador del objeto de metadatos del cual el valor
			           |del atributo ""Marca para borrar"" está establecida False no es válido.';
			           |tr = '""Silme işareti"" öznitelik değeri 
			           |""Yanlış"" olarak ayarlanmış olan meta veri nesnesi kimlik silme işlemi geçersizdir.';
			           |it = 'La cancellazione degli identificatori degli oggetti, il cui valore
			           |del requisito ""Contrassegno di cancellazione"" è impostato a False non è ammessa.';
			           |de = 'Das Löschen der Identifikatoren der Objekte mit dem Attribut
			           |wert ""Löschmarkierung"", der auf ""False"" gesetzt ist, ist nicht erlaubt.'"));
	EndIf;
	
EndProcedure

// For internal use only.
Procedure ListFormOnCreateAtServer(Form) Export
	
	Parameters = Form.Parameters;
	Items  = Form.Items;
	
	SetListOrderAndAppearance(Form);
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(Form, "SelectionPick");
		Form.WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	Parameters.Property("SelectMetadataObjectsGroups", Form.SelectMetadataObjectsGroups);
	
EndProcedure

// For internal use only.
Procedure ItemFormOnCreateAtServer(Form) Export
	
	ExtensionsObjects = IsExtensionObject(Form.Object.Ref);
	
	Parameters = Form.Parameters;
	Items  = Form.Items;
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Form.ReadOnly = True;
	
	Form.EmptyRefPresentation = String(TypeOf(Form.Object.EmptyRefValue));
	
	If NOT Users.IsFullUser(, Not ExtensionsObjects)
	 OR CannotChangeFullName(Form.Object)
	 OR Not ExtensionsObjects AND Common.IsSubordinateDIBNode()
	 OR ExtensionsObjects AND Catalogs.ExtensionObjectIDs.ExtensionObjectDisabled(Form.Object.Ref) Then
		
		Items.FormEnableEditing.Visible = False;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For the ImportDataToSubordinateNode procedure.
Procedure FindDuplicatesOnImportDataToSubordinateNode(DataExported, Filter, ObjectToImport, ObjectToImportRef, ItemsToImportTable)
	
	Rows = DataExported.FindRows(Filter);
	For Each Row In Rows Do
		
		If Row.Ref <> ObjectToImportRef
		   AND ItemsToImportTable.Find(Row.Ref, "Ref") = Undefined Then
			
			UpdateMarkedForDeletionItemProperties(Row,,, True);
			Row.NewRef = ObjectToImportRef;
			Row.DuplicateUpdated = True;
			ObjectToImport.AdditionalProperties.Insert("IsDuplicateReplacement");
			// Replacing new references to the duplicate with a new reference specified for the duplicate (if any).
			PreviousDuplicates = DataExported.FindRows(New Structure("NewRef", Row.Ref));
			For Each PreviousDuplicate In PreviousDuplicates Do
				UpdateMarkedForDeletionItemProperties(PreviousDuplicate,,, True);
				PreviousDuplicate.NewRef = ObjectToImportRef;
				PreviousDuplicate.DuplicateUpdated = True;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

Procedure UpdateData(HasChanges, HasDeletedItems, CheckOnly,
			HasCriticalChanges, ListOfCriticalChanges, ExtensionsObjects)
	
	ExtensionProperties = New Structure;
	ExtensionProperties.Insert("AttachedExtensionsNames",
		ExtensionNames(ConfigurationExtensionsSource.SessionApplied));
	ExtensionProperties.Insert("UnattachedExtensionsNames",
		ExtensionNames(ConfigurationExtensionsSource.SessionDisabled));
	
	MetadataObjectProperties = MetadataObjectProperties(ExtensionsObjects);
	
	// Found - this status indicates that ID is found for the metadata object.
	MetadataObjectProperties.Columns.Add("Found", New TypeDescription("Boolean"));
	
	// The update procedure includes the following steps:
	// 1. Renaming metadata objects (taking child subsystems into account).
	// 2. Updating predefined IDs (metadata object collections).
	// 3. Updating IDs of metadata objects that have metadata object key.
	// 4. Updating IDs of metadata objects that do not have metadata object key.
	// 5. During steps 3 and 4, setting deletion mark of ID duplicates (by full names).
	// 6. Adding new metadata object IDs.
	// 7. Updating parents of metadata object IDs and saving updated items.
	
	ExtensionsVersion = SessionParameters.ExtensionsVersion;
	
	Lock = New DataLock;
	LockItem = Lock.Add(CatalogName(ExtensionsObjects));
	If ExtensionsObjects Then
		LockItem = Lock.Add("InformationRegister.ExtensionVersionObjectIDs");
		LockItem.SetValue("ExtensionsVersion", ExtensionsVersion);
	EndIf;
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		DataExported = ExportAllIDs(ExtensionsObjects);
		DataExported.Columns.Add("Updated", New TypeDescription("Boolean"));
		DataExported.Columns.Add("MetadataObject");
		DataExported.Columns.Delete("NewRef");
		
		MetadataObjectRenamingList = "";
		If NOT ExtensionsObjects
		   AND NOT Common.IsSubordinateDIBNode() Then
			// Renaming the full names before processing (only for master node when in DIB).
			// Not supported for extensions.
			RenameFullNames(DataExported, MetadataObjectRenamingList, HasCriticalChanges);
		EndIf;
		
		ProcessMetadataObjectIDs(DataExported, MetadataObjectProperties, ExtensionsObjects,
			ExtensionProperties, HasDeletedItems, HasCriticalChanges, MetadataObjectRenamingList);
		
		NewMetadataObjectsList = "";
		AddNewMetadataObjectsIDs(DataExported, MetadataObjectProperties, ExtensionsObjects,
			HasCriticalChanges, NewMetadataObjectsList);
		
		ListOfCriticalChanges = "";
		If ValueIsFilled(MetadataObjectRenamingList) Then
			ListOfCriticalChanges = NStr("ru = 'Переименование идентификаторов объектов метаданных СтароеПолноеИмя -> НовоеПолноеИмя:'; en = 'Renamed metadata object IDs PreviousFullName -> NewFullName:'; pl = 'Zmień nazwę identyfikatorów obiektów metadanych PreviousFullName -> NewFullName:';es_ES = 'Renombrar los identificadores de los objetos de metadatos PreviousFullName -> NewFullName:';es_CO = 'Renombrar los identificadores de los objetos de metadatos PreviousFullName -> NewFullName:';tr = 'Meta veri nesnelerinin kimliklerinin yeniden adlandırılması PreviousFullName -> NewFullName:';it = 'Ridenominazione degli identificatori degli oggetti dei metadati VecchioNomeCompleto -> NuovoNomeCompleto:';de = 'Benennen Sie die IDs der Metadatenobjekte um PreviousFullName -> NewFullName:'")
				+ Chars.LF + MetadataObjectRenamingList + Chars.LF + Chars.LF;
		EndIf;
		If ValueIsFilled(NewMetadataObjectsList) Then
			ListOfCriticalChanges = ListOfCriticalChanges
				+ NStr("ru = 'Добавление новых идентификаторов объектов метаданных:'; en = 'Added metadata object IDs:'; pl = 'Dodaj nowe identyfikatory obiektów metadanych:';es_ES = 'Añadir los nuevos identificadores del objeto de metadatos:';es_CO = 'Añadir los nuevos identificadores del objeto de metadatos:';tr = 'Yeni meta veri nesne tanımlayıcıları ekle:';it = 'Aggiunta di nuovi identificatori degli oggetti dei metadati:';de = 'Fügen Sie neue Metadatenobjekt-IDs hinzu:'")
				+ Chars.LF + NewMetadataObjectsList + Chars.LF;
		EndIf;
		
		If Not CheckOnly
		   AND Not ExtensionsObjects
		   AND ValueIsFilled(ListOfCriticalChanges)
		   AND Common.IsSubordinateDIBNode() Then
			
			EventName = NStr("ru = 'Идентификаторы объектов метаданных.Требуется загрузить критичные изменения'; en = 'Metadata object IDs.Import of critical changes required'; pl = 'Identyfikator obiektu IDs.Importuj krytyczne zmiany';es_ES = 'Identificadores de objetos de metadatos.Importar los cambios críticos';es_CO = 'Identificadores de objetos de metadatos.Importar los cambios críticos';tr = 'Meta veri nesne kimlikleri. Kritik değişiklikleri içe aktar';it = 'Identificatori degli oggetti dei metadati. È necessario caricare modifiche critiche';de = 'Metadatenobjekt-IDs. Importieren Sie wichtige Änderungen'",
				CommonClientServer.DefaultLanguageCode());
			
			WriteLogEvent(EventName, EventLogLevel.Error, , , ListOfCriticalChanges);
			
			RaiseByError(ExtensionsObjects,
				NStr("ru = 'Критичные изменения могут быть выполнены только
				           |в главном узле распределенной информационной базы.
				           |Состав требуемых изменений см. в журнале регистрации.'; 
				           |en = 'Critical changes can only be applied
				           |to the master node of the distributed infobase.
				           |For the list of changes, see the event log.'; 
				           |pl = 'Zmiany krytyczne można zastosować tylko
				           |do węzła nadrzędnego dystrybucji bazy informacyjnej.
				           |Lista zmian znajduje się w dzienniku wydarzeń.';
				           |es_ES = 'Los cambios críticos no pueden ser realizados solo
				           |en el nodo principal de la base de información distribuida.
				           |El contenido de los cambios requeridos véase en el registro de eventos.';
				           |es_CO = 'Los cambios críticos no pueden ser realizados solo
				           |en el nodo principal de la base de información distribuida.
				           |El contenido de los cambios requeridos véase en el registro de eventos.';
				           |tr = 'Önemli değişiklikler yalnızca
				           |dağıtılmış Infobase''in ana düğümüne uygulanabilir.
				           |Değişiklik listesi için olay günlüğüne bakın.';
				           |it = 'Modifiche critiche possono essere effettuate solo
				           |nel nodo principale del database informatico suddiviso.
				           |Vedere la composizione delle modifiche necessarie nel registro di registrazione.';
				           |de = 'Wichtige Änderungen können nur
				           |am Hauptknoten der verteilten Informationsbasis vorgenommen werden.
				           |Die erforderlichen Änderungen finden Sie im Ereignisprotokoll.'"));
		EndIf;
		
		UpdateMetadataObjectIDs(DataExported, MetadataObjectProperties, ExtensionsObjects,
			ExtensionProperties, ExtensionsVersion, HasChanges, CheckOnly);
		
		If Not CheckOnly Then
			If ValueIsFilled(ListOfCriticalChanges) Then
				WriteLogEvent(?(ExtensionsObjects,
						NStr("ru = 'Идентификаторы объектов расширений.Выполнены критичные изменения'; en = 'Extension object IDs.Critical changes applied'; pl = 'Identyfikatory obiektów rozszerzeń.Dokonano krytycznych zmian';es_ES = 'Identificadores del objeto de extensiones.Cambios críticos hechos';es_CO = 'Identificadores del objeto de extensiones.Cambios críticos hechos';tr = 'Meta veri nesne kimlikleri. Kritik değişiklikler yapıldı';it = 'Identificatori degli oggetti delle estensioni. Modifiche critiche effettuate';de = 'Identifikatoren von Erweiterungsobjekten. Kritische Änderungen wurden vorgenommen'",
							CommonClientServer.DefaultLanguageCode()),
						NStr("ru = 'Идентификаторы объектов метаданных.Выполнены критичные изменения'; en = 'Metadata object IDs.Critical changes applied'; pl = 'Identyfikator obiektu metadanych. Wprowadzono zmiany krytyczne';es_ES = 'Identificadores del objeto de metadatos.Cambios críticos hechos';es_CO = 'Identificadores del objeto de metadatos.Cambios críticos hechos';tr = 'Meta veri nesne kimlikleri. Kritik değişiklikler yapıldı';it = 'Identificatori degli oggetti dei metadati. Modifiche critiche effettuate';de = 'Metadatenobjekt-IDs. Kritische Änderungen vorgenommen'",
							CommonClientServer.DefaultLanguageCode())),
					EventLogLevel.Information,
					,
					,
					ListOfCriticalChanges,
					EventLogEntryTransactionMode.Transactional);
			EndIf;
			
			If Not ExtensionsObjects
			   AND Not Common.IsSubordinateDIBNode() Then
				
				PrepareNewSubsystemsListInMasterNode(DataExported);
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function ExportAllIDs(ExtensionsObjects = False)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref AS Ref,
	|	IDs.PredefinedDataName AS PredefinedDataName,
	|	IDs.Parent AS Parent,
	|	IDs.DeletionMark AS DeletionMark,
	|	IDs.Description AS Description,
	|	IDs.CollectionOrder,
	|	IDs.Name,
	|	IDs.Synonym,
	|	IDs.FullName,
	|	IDs.FullSynonym,
	|	IDs.NoData,
	|	IDs.EmptyRefValue,
	|	IDs.MetadataObjectKey AS KeyStorage,
	|	IDs.NewRef,
	|	&ExtensionName AS ExtensionName,
	|	&ExtensionHashsum AS ExtensionHashsum
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs";
	ClarifyCatalogNameInQueryText(Query.Text, ExtensionsObjects);
	Query.Text = StrReplace(Query.Text, "&ExtensionName",
		?(ExtensionsObjects, "IDs.ExtensionName", """"""));
	Query.Text = StrReplace(Query.Text, "&ExtensionHashsum",
		?(ExtensionsObjects, "IDs.ExtensionHashsum", """"""));
	
	DataExported = Query.Execute().Unload();
	DataExported.Columns.Add("MetadataObjectKey");
	DataExported.Columns.Add("NoMetadataObjectKey", New TypeDescription("Boolean"));
	DataExported.Columns.Add("IsCollection",              New TypeDescription("Boolean"));
	DataExported.Columns.Add("IsNew",                  New TypeDescription("Boolean"));
	
	// Ordering the IDs before processing.
	For each Row In DataExported Do
		If TypeOf(Row.KeyStorage) = Type("ValueStorage") Then
			Row.MetadataObjectKey = Row.KeyStorage.Get();
		Else
			Row.MetadataObjectKey = Undefined;
		EndIf;
		
		Row.NoMetadataObjectKey = Row.MetadataObjectKey = Undefined
		                               OR Row.MetadataObjectKey = Type("Undefined");
	EndDo;
	
	DataExported.Indexes.Add("Ref");
	DataExported.Indexes.Add("FullName");
	
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	
	For each CollectionProperties In CollectionsProperties Do
		CollectionID = CollectionID(CollectionProperties.ID, ExtensionsObjects);
		Row = DataExported.Find(CollectionID, "Ref");
		If Row = Undefined Then
			Row = DataExported.Add();
			Row.Ref   = CollectionID;
			Row.IsNew = True;
		EndIf;
		Row.IsCollection = True;
	EndDo;
	
	DataExported.Sort("IsCollection DESC,
	                     |DeletionMark ASC,
	                     |NoMetadataObjectKey ASC");
	
	Return DataExported;
	
EndFunction

Procedure RenameFullNames(DataExported, MetadataObjectRenamingList = "", HasCriticalChanges = False)
	
	RenamingTable = StandardSubsystemsCached.RenamingTableForCurrentVersion();
	RenamedItems = New Map;
	
	For Each RenamingDetails In RenamingTable Do
		PreviousFullNameLength = StrLen(RenamingDetails.PreviousFullName);
		IsSubsystem = Upper(Left(RenamingDetails.PreviousFullName, 11)) = Upper("Subsystem.");
		
		For Each Row In DataExported Do
			If Row.IsCollection Then
				Continue;
			EndIf;
			
			NewFullName = "";
			
			If IsSubsystem Then
				If Upper(Left(Row.FullName, PreviousFullNameLength))
				     = Upper(RenamingDetails.PreviousFullName) Then
					
					NewFullName = RenamingDetails.NewFullName
						+ Mid(Row.FullName, PreviousFullNameLength + 1);
				EndIf;
			Else
				If Upper(Row.FullName) = Upper(RenamingDetails.PreviousFullName) Then
					NewFullName = RenamingDetails.NewFullName;
				EndIf;
			EndIf;
			
			If Not ValueIsFilled(NewFullName) Then
				Continue;
			EndIf;
			
			Renaming = RenamedItems.Get(Row);
			If Renaming = Undefined Then
				Renaming = New Structure;
				Renaming.Insert("PreviousFullName", Row.FullName);
				Renaming.Insert("NewFullName",  NewFullName);
				RenamedItems.Insert(Row, Renaming);
			Else
				Renaming.NewFullName = NewFullName;
			EndIf;
			Row.FullName = NewFullName;
		EndDo;
	EndDo;
	
	For Each Row In DataExported Do
		Renaming = RenamedItems.Get(Row);
		If Renaming = Undefined Then
			Continue;
		EndIf;
		
		HasCriticalChanges = True;
		MetadataObjectRenamingList = MetadataObjectRenamingList
			+ ?(ValueIsFilled(MetadataObjectRenamingList), "," + Chars.LF, "")
			+ Renaming.PreviousFullName + " -> " + Renaming.NewFullName;
	EndDo;
	
EndProcedure

Procedure ProcessMetadataObjectIDs(DataExported, MetadataObjectProperties, ExtensionsObjects,
			ExtensionProperties, HasDeletedItems, HasCriticalChanges, MetadataObjectRenamingList)
	
	// Processing the metadata object IDs.
	For Each Properties In DataExported Do
		
		// Validating and updating properties of the metadata object collection IDs.
		If Properties.IsCollection Then
			CheckUpdateCollectionProperties(Properties, ExtensionsObjects);
			Continue;
		EndIf;
		
		If ExtensionsObjects
		   AND ExtensionProperties.UnattachedExtensionsNames[Properties.ExtensionName] <> Undefined Then
			// Unattached extensions items remain unchanged, so you can use them after correcting errors in 
			// extensions to ensure that the data processor that deletes marked objects does not delete 
			// associated data.
			Continue;
		EndIf;
		
		If ExtensionsObjects
		   AND ExtensionProperties.AttachedExtensionsNames[Properties.ExtensionName] = Undefined Then
			
			PropertiesUpdated = False;
			UpdateMarkedForDeletionItemProperties(Properties, PropertiesUpdated, HasDeletedItems);
			If PropertiesUpdated Then
				Properties.Updated = True;
			EndIf;
		EndIf;
		
		MetadataObjectKey = Properties.MetadataObjectKey;
		MetadataObject = MetadataObjectByKey(MetadataObjectKey);
		
		If MetadataObject = Undefined Then
			// If the metadata object has no key, it can be found by the full name only.
			MetadataObject = MetadataFindByFullName(Properties.FullName);
			If MetadataObject = Undefined AND ExtensionsObjects Then
				MetadataObject = ExtensionMetadataFindByFullName(Properties);
			EndIf;
		Else
			// If the metadata object is deleted for restructuring, old ID must be used for the new metadata 
			// object and old metadata objects must get new IDs.
			// 
			If Upper(Left(MetadataObject.Name, StrLen("Delete"))) =  Upper("Delete")
			   AND Upper(Left(Properties.Name,         StrLen("Delete"))) <> Upper("Delete") Then
				
				NewMetadataObject = MetadataFindByFullName(Properties.FullName);
				If NewMetadataObject <> Undefined Then
					MetadataObject = NewMetadataObject;
					MetadataObjectKey = Undefined; // Required for the ID update.
				EndIf;
			EndIf;
		EndIf;
		
		// If the metadata object is found by key or full name, the metadata object property row must be 
		// prepared.
		If MetadataObject <> Undefined Then
			ObjectProperties = MetadataObjectProperties.Find(MetadataObject.FullName(), "FullName");
			If ObjectProperties = Undefined Then
				MetadataObject = Undefined;
			Else
				Properties.MetadataObject = MetadataObject;
			EndIf;
		EndIf;
		
		If MetadataObject = Undefined OR ObjectProperties.Found Then
			// If the metadata object is not found or found repeatedly, the ID must be marked for deletion.
			// 
			IsDuplicate = MetadataObject <> Undefined AND ObjectProperties.Found;
			PropertiesUpdated = False;
			UpdateMarkedForDeletionItemProperties(Properties, PropertiesUpdated, HasDeletedItems, IsDuplicate);
			If PropertiesUpdated Then
				Properties.Updated = True;
			EndIf;
		Else
			// Updating properties of the existing metadata objects (if any changes were made).
			ObjectProperties.Found = True;
			If Properties.Description              <> ObjectProperties.Description
			 OR Properties.CollectionOrder          <> ObjectProperties.CollectionOrder
			 OR Properties.Name                       <> ObjectProperties.Name
			 OR Properties.Synonym                   <> ObjectProperties.Synonym
			 OR Properties.FullName                 <> ObjectProperties.FullName
			 OR Properties.FullSynonym             <> ObjectProperties.FullSynonym
			 OR Properties.NoData                 <> ObjectProperties.NoData
			 OR Properties.EmptyRefValue      <> ObjectProperties.EmptyRefValue
			 OR Properties.ExtensionName             <> ObjectProperties.ExtensionName
			 OR Properties.ExtensionHashsum        <> ObjectProperties.ExtensionHashsum
			 OR Properties.PredefinedDataName <> ObjectProperties.PredefinedDataName
			 OR Properties.DeletionMark
			 OR MetadataObjectKey = Undefined
			 OR ObjectProperties.NoMetadataObjectKey
			     AND MetadataObjectKey <> Type("Undefined") Then
				
				If Upper(Properties.FullName) <> Upper(ObjectProperties.FullName) Then
					HasCriticalChanges = True;
					MetadataObjectRenamingList = MetadataObjectRenamingList
						+ ?(ValueIsFilled(MetadataObjectRenamingList), "," + Chars.LF, "")
						+ Properties.FullName + " -> " + ObjectProperties.FullName;
				EndIf;
				
				// Setting new properties for the metadata object ID.
				FillPropertyValues(Properties, ObjectProperties);
				
				Properties.PredefinedDataName = ObjectProperties.PredefinedDataName;
				
				If MetadataObjectKey = Undefined
				 OR ObjectProperties.NoMetadataObjectKey
				     AND MetadataObjectKey <> Type("Undefined") Then
					
					Properties.MetadataObjectKey = MetadataObjectKey(ObjectProperties.FullName);
				EndIf;
				
				Properties.DeletionMark = False;
				Properties.Updated = True;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function ExtensionMetadataFindByFullName(Properties)
	
	If Properties.ExtensionName = ""
	 Or Not StrStartsWith(Properties.FullName, "?") Then
		Return Undefined;
	EndIf;
	
	// Restoring links to the ID of the metadata object belonging to the extension that was temporarily 
	// deleted and is being restored.
	BracketPosition = StrFind(Properties.FullName, "(");
	OriginalFullName = Mid(Properties.FullName, 3, BracketPosition - 4);
	MetadataObject = MetadataFindByFullName(OriginalFullName);
	
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	
	ObjectExtension = MetadataObject.ConfigurationExtension();
	
	If ObjectExtension = Undefined
	 Or ObjectExtension.Name <> Mid(Properties.ExtensionName, 3)
	 Or Base64String(ObjectExtension.HashSum) <> Mid(Properties.ExtensionHashsum, 3) Then
		
		Return Undefined;
	EndIf;
	
	Return MetadataObject;
	
EndFunction

Procedure AddNewMetadataObjectsIDs(DataExported, MetadataObjectProperties, ExtensionsObjects,
			HasCriticalChanges, NewMetadataObjectsList)
	
	ObjectsProperties = MetadataObjectProperties.FindRows(New Structure("Found", False));
	
	For Each ObjectProperties In ObjectsProperties Do
		Properties = DataExported.Add();
		FillPropertyValues(Properties, ObjectProperties);
		Properties.IsNew = True;
		Properties.Ref = NewCatalogRef(ExtensionsObjects);
		Properties.DeletionMark  = False;
		Properties.MetadataObject = ObjectProperties.MetadataObject;
		Properties.MetadataObjectKey = MetadataObjectKey(Properties.FullName);
		HasCriticalChanges = True;
		NewMetadataObjectsList = NewMetadataObjectsList
			+ ?(ValueIsFilled(NewMetadataObjectsList), "," + Chars.LF, "")
			+ ObjectProperties.FullName;
	EndDo;
	
EndProcedure

Procedure UpdateMetadataObjectIDs(DataExported, MetadataObjectProperties, ExtensionsObjects,
			ExtensionProperties, ExtensionsVersion, HasChanges, CheckOnly)
		
		If ExtensionsObjects Then
			RecordSet = InformationRegisters.ExtensionVersionObjectIDs.CreateRecordSet();
			RecordSet.Filter.ExtensionsVersion.Set(ExtensionsVersion);
			RecordSet.Read();
			RecordTable = RecordSet.Unload();
			RecordTable.Columns.Add("Delete", New TypeDescription("Boolean"));
			RecordTable.FillValues(True, "Delete");
			RecordTable.Indexes.Add("ID, FullObjectName, ExtensionsVersion");
			UpdateRecordSet = False;
		EndIf;
		
		For Each Properties In DataExported Do
			
			// Updating parents of the metadata object IDs.
			If Not Properties.IsCollection Then
				ObjectProperties = MetadataObjectProperties.Find(Properties.FullName, "FullName");
				NewParent = EmptyCatalogRef(ExtensionsObjects);
				
				If ObjectProperties <> Undefined Then
					If Not ValueIsFilled(ObjectProperties.ParentFullName) Then
						// This is a collection of metadata objects.
						NewParent = ObjectProperties.Parent;
					Else
						// This is not a collection of metadata objects. Example: subsystem.
						ParentDetails = DataExported.Find(ObjectProperties.ParentFullName, "FullName");
						If ParentDetails <> Undefined Then
							NewParent = ParentDetails.Ref;
						EndIf;
					EndIf;
				EndIf;
				
				If Properties.Parent <> NewParent Then
					Properties.Parent = NewParent;
					Properties.Updated = True;
				EndIf;
				
				If ExtensionsObjects
				   AND Properties.DeletionMark = False
				   AND ExtensionProperties.UnattachedExtensionsNames[Properties.ExtensionName] = Undefined Then
					
					Filter = New Structure;
					Filter.Insert("ExtensionsVersion", ExtensionsVersion);
					Filter.Insert("ID",    Properties.Ref);
					Filter.Insert("FullObjectName", Properties.FullName);
					Rows = RecordTable.FindRows(Filter);
					If Rows.Count() = 0 Then
						UpdateRecordSet = True;
						FillPropertyValues(RecordTable.Add(), Filter);
					Else
						Rows[0].Delete = False;
					EndIf;
				EndIf;
			EndIf;
			
			// Updating the metadata object IDs.
			If Properties.IsNew Then
				TableObject = CreateCatalogItem(ExtensionsObjects);
				TableObject.SetNewObjectRef(Properties.Ref);
				
			ElsIf Properties.Updated Then
				TableObject = Properties.Ref.GetObject();
			Else
				Continue;
			EndIf;
			
			HasChanges = True;
			If CheckOnly Then
				Return;
			EndIf;
			
			FillPropertyValues(TableObject, Properties);
			TableObject.MetadataObjectKey = New ValueStorage(Properties.MetadataObjectKey);
			TableObject.DataExchange.Load = True;
			CheckObjectBeforeWrite(TableObject, True);
			TableObject.Write();
		EndDo;
		
		If ExtensionsObjects Then
			RecordTable.Indexes.Add("Delete");
			Rows = RecordTable.FindRows(New Structure("Delete", True));
			If Rows.Count() > 0 Then
				UpdateRecordSet = True;
				For Each Row In Rows Do
					RecordTable.Delete(Row);
				EndDo;
			EndIf;
			If RecordTable.Count() = 0
			   AND ValueIsFilled(ExtensionsVersion) Then
				// Adding records if the extension has no metadata objects, to get True when checking cache.
				// 
				RecordTable.Add().ExtensionsVersion = ExtensionsVersion;
				UpdateRecordSet = True;
			EndIf;
			If UpdateRecordSet Then
				HasChanges = True;
				If CheckOnly Then
					Return;
				EndIf;
				RecordSet.Load(RecordTable);
				RecordSet.Write();
			EndIf;
		EndIf;
		
EndProcedure

Procedure UpdateMarkedForDeletionItemProperties(Properties, PropertiesUpdated = False, HasDeletedItems = False, IsDuplicate = False)
	
	ExtensionsObjects = IsExtensionObject(Properties.Ref);
	
	If NOT Properties.DeletionMark
	 OR ValueIsFilled(Properties.Parent)
	 OR Left(Properties.Description, 1)  <> "?"
	 OR Left(Properties.Name, 1)           <> "?"
	 OR Left(Properties.Synonym, 1)       <> "?"
	 OR Left(Properties.FullName, 1)     <> "?"
	 OR Left(Properties.FullSynonym, 1) <> "?"
	 OR ExtensionsObjects AND Left(Properties.ExtensionName, 1)      <> "?"
	 OR ExtensionsObjects AND Left(Properties.ExtensionHashsum, 1) <> "?"
	 OR StrFind(Properties.FullName, "(") = 0
	 OR Properties.EmptyRefValue  <> Undefined
	 OR IsDuplicate Then
		
		If NOT Properties.DeletionMark Or Left(Properties.FullName, 1) <> "?" Then
			HasDeletedItems = True;
		EndIf;
		
		// Setting new properties for the metadata object ID.
		Properties.DeletionMark       = True;
		Properties.Parent              = EmptyCatalogRef(IsExtensionObject(Properties.Ref));
		Properties.Description          = InsertQuestionMark(Properties.Description);
		Properties.Name                   = InsertQuestionMark(Properties.Name);
		Properties.Synonym               = InsertQuestionMark(Properties.Synonym);
		Properties.FullName             = UniqueFullName(Properties);
		Properties.FullSynonym         = InsertQuestionMark(Properties.FullSynonym);
		Properties.EmptyRefValue  = Undefined;
		
		If ExtensionsObjects Then
			Properties.ExtensionName      = InsertQuestionMark(Properties.ExtensionName);
			Properties.ExtensionHashsum = InsertQuestionMark(Properties.ExtensionHashsum);
		EndIf;
		
		If IsDuplicate Then
			If TypeOf(Properties.MetadataObjectKey) = Type("ValueStorage") Then
				Properties.MetadataObjectKey = New ValueStorage(Undefined);
			Else
				Properties.MetadataObjectKey = Undefined;
			EndIf;
		EndIf;
		PropertiesUpdated = True;
	EndIf;
	
EndProcedure

Procedure CheckUpdateCollectionProperties(Val CurrentProperties, ExtensionsObjects)
	
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	NewProperties = CollectionsProperties.Find(CurrentProperties.Ref.UUID(), "ID");
	
	CollectionDescription = NewProperties.Synonym;
	
	If CurrentProperties.Description              <> CollectionDescription
	 OR CurrentProperties.CollectionOrder          <> NewProperties.CollectionOrder
	 OR CurrentProperties.Name                       <> NewProperties.Name
	 OR CurrentProperties.Synonym                   <> NewProperties.Synonym
	 OR CurrentProperties.FullName                 <> NewProperties.Name
	 OR CurrentProperties.FullSynonym             <> NewProperties.Synonym
	 OR CurrentProperties.NoData                 <> False
	 OR CurrentProperties.EmptyRefValue      <> Undefined
	 OR CurrentProperties.PredefinedDataName <> ""
	 OR CurrentProperties.DeletionMark           <> False
	 OR CurrentProperties.MetadataObjectKey     <> Undefined Then
		
		// Setting new properties.
		CurrentProperties.Description              = CollectionDescription;
		CurrentProperties.CollectionOrder          = NewProperties.CollectionOrder;
		CurrentProperties.Name                       = NewProperties.Name;
		CurrentProperties.Synonym                   = NewProperties.Synonym;
		CurrentProperties.FullName                 = NewProperties.Name;
		CurrentProperties.FullSynonym             = NewProperties.Synonym;
		CurrentProperties.NoData                 = False;
		CurrentProperties.EmptyRefValue      = Undefined;
		CurrentProperties.PredefinedDataName = "";
		CurrentProperties.DeletionMark           = False;
		CurrentProperties.MetadataObjectKey     = Undefined;
		
		CurrentProperties.Updated = True;
	EndIf;
	
EndProcedure

Function MetadataObjectKey(FullName)
	
	PointPosition = StrFind(FullName, ".");
	
	MOClass = Left( FullName, PointPosition-1);
	MetadataObjectName   = Mid(FullName, PointPosition+1);
	
	If Upper(MOClass) = Upper("ExchangePlan") Then
		Return Type(MOClass + "Ref." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("Constant") Then
		Return TypeOf(Common.ObjectManagerByFullName(FullName));
		
	ElsIf Upper(MOClass) = Upper("Catalog") Then
		Return Type(MOClass + "Ref." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("Document") Then
		Return Type(MOClass + "Ref." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("DocumentJournal") Then
		Return TypeOf(Common.ObjectManagerByFullName(FullName));
		
	ElsIf Upper(MOClass) = Upper("Report") Then
		Return Type(MOClass + "Object." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("DataProcessor") Then
		Return Type(MOClass + "Object." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("ChartOfCharacteristicTypes") Then
		Return Type(MOClass + "Ref." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("ChartOfAccounts") Then
		Return Type(MOClass + "Ref." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("ChartOfCalculationTypes") Then
		Return Type(MOClass + "Ref." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("InformationRegister") Then
		Return Type(MOClass + "RecordKey." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("AccumulationRegister") Then
		Return Type(MOClass + "RecordKey." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("AccountingRegister") Then
		Return Type(MOClass + "RecordKey." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("CalculationRegister") Then
		Return Type(MOClass + "RecordKey." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("BusinessProcess") Then
		Return Type(MOClass + "Ref." + MetadataObjectName);
		
	ElsIf Upper(MOClass) = Upper("Task") Then
		Return Type(MOClass + "Ref." + MetadataObjectName);
	Else
		// No metadata object key.
		Return Type("Undefined");
	EndIf;
	
EndFunction 

Function IdenticalMetadataObjectKeys(Properties, Object)
	
	Return Properties.MetadataObjectKey = Object.MetadataObjectKey.Get();
	
EndFunction

Function MetadataObjectKeyMatchesFullName(IDProperties)
	
	CheckResult = New Structure;
	CheckResult.Insert("NotCorresponds", True);
	CheckResult.Insert("MetadataObjectKey", Undefined);
	
	MetadataObjectKey = IDProperties.MetadataObjectKey.Get();
	ExtensionsObjects = IsExtensionObject(IDProperties.Ref);
	
	If MetadataObjectKey <> Undefined
	   AND MetadataObjectKey <> Type("Undefined") Then
		// Key is specified; searching for metadata object by the key.
		CheckResult.Insert("MetadataObjectKey", MetadataObjectKey);
		MetadataObject = MetadataObjectByKey(MetadataObjectKey);
		If MetadataObject <> Undefined Then
			CheckResult.NotCorresponds = MetadataObject.FullName() <> IDProperties.FullName;
		EndIf;
	Else
		// Key is not specified; searching for metadata object by the full name.
		MetadataObject = MetadataFindByFullName(IDProperties.FullName);
		If MetadataObject = Undefined Then
			// Collection might have been specified.
			
			Row = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects).Find(
				IDProperties.Ref.UUID(), "ID");
			
			If Row <> Undefined Then
				MetadataObject = Metadata[Row.Name];
				CheckResult.NotCorresponds = Row.Name <> IDProperties.FullName;
			EndIf;
		Else
			CheckResult.NotCorresponds = False;
		EndIf;
	EndIf;
	
	CheckResult.Insert("MetadataObject", MetadataObject);
	
	Return CheckResult;
	
EndFunction

Function CannotChangeFullName(Object)
	
	ExtensionsObjects = IsExtensionObject(Object);
	If IsCollection(Object.Ref, ExtensionsObjects) Then
		Return True;
	EndIf;
	
	PointPosition = StrFind(Object.FullName, ".");
	BaseTypeName = Left(Object.FullName, PointPosition -1);
	
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	CollectionProperties = CollectionsProperties.Find(BaseTypeName, "SingularName");
	
	If CollectionProperties <> Undefined
	   AND NOT CollectionProperties.NoMetadataObjectKey Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function MetadataObjectByKey(MetadataObjectKey)
	
	MetadataObject = Undefined;
	
	If TypeOf(MetadataObjectKey) = Type("Type") Then
		MetadataObject = Metadata.FindByType(MetadataObjectKey);
	EndIf;
	
	Return MetadataObject;
	
EndFunction

Function MetadataObjectProperties(ExtensionsObjects, CollectionsProperties = Undefined)
	
	ParentTypesArray = New Array;
	ParentTypesArray.Add(TypeOf(EmptyCatalogRef(ExtensionsObjects)));
	
	MetadataObjectProperties = New ValueTable;
	MetadataObjectProperties.Columns.Add("Description",              New TypeDescription("String",, New StringQualifiers(150)));
	MetadataObjectProperties.Columns.Add("FullName",                 New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties.Columns.Add("ParentFullName",         New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties.Columns.Add("CollectionOrder",          New TypeDescription("Number"));
	MetadataObjectProperties.Columns.Add("Parent",                  New TypeDescription(ParentTypesArray));
	MetadataObjectProperties.Columns.Add("Name",                       New TypeDescription("String",, New StringQualifiers(150)));
	MetadataObjectProperties.Columns.Add("PredefinedDataName", New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectProperties.Columns.Add("Synonym",                   New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectProperties.Columns.Add("FullSynonym",             New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties.Columns.Add("NoData",                 New TypeDescription("Boolean"));
	MetadataObjectProperties.Columns.Add("NoMetadataObjectKey", New TypeDescription("Boolean"));
	MetadataObjectProperties.Columns.Add("ExtensionName",             New TypeDescription("String",, New StringQualifiers(128)));
	MetadataObjectProperties.Columns.Add("ExtensionHashsum",        New TypeDescription("String",, New StringQualifiers(30)));
	MetadataObjectProperties.Columns.Add("EmptyRefValue");
	MetadataObjectProperties.Columns.Add("MetadataObject");
	
	If CollectionsProperties = Undefined Then
		CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	EndIf;
	
	PredefinedDataNames = ?(ExtensionsObjects,
		Metadata.Catalogs.ExtensionObjectIDs,
		Metadata.Catalogs.MetadataObjectIDs).GetPredefinedNames();
	
	PredefinedItemNames = New Map;
	For Each PredefinedItemName In PredefinedDataNames Do
		PredefinedItemNames.Insert(PredefinedItemName, False);
	EndDo;
	
	If Not ExtensionsObjects Or ValueIsFilled(SessionParameters.AttachedExtensions) Then
		For each CollectionProperties In CollectionsProperties Do
			AddMetadataObjectProperties(Metadata[CollectionProperties.Name], CollectionProperties,
				MetadataObjectProperties, ExtensionsObjects, PredefinedItemNames);
		EndDo;
		MetadataObjectProperties.Indexes.Add("FullName");
	EndIf;
	
	Return MetadataObjectProperties;
	
EndFunction

Procedure AddMetadataObjectProperties(Val MetadataObjectsCollection,
                                             Val CollectionProperties,
                                             Val MetadataObjectProperties,
                                             Val ExtensionsObjects,
                                             Val PredefinedItemNames,
                                             Val ParentFullName = "",
                                             Val ParentFullSynonym = "")
	
	For Each MetadataObject In MetadataObjectsCollection Do
		
		FullName = MetadataObject.FullName();
		Extension = MetadataObject.ConfigurationExtension();
		ExtensionName      = ?(Extension = Undefined, "", Extension.Name);
		ExtensionHashsum = ?(Extension = Undefined, "", Base64String(Extension.HashSum));
		If ValueIsFilled(ExtensionName) <> ExtensionsObjects Then
			Continue;
		EndIf;
		
		If StrFind(CollectionProperties.SingularName, "Subsystem") <> 0 Then
			MetadataFindByFullName(FullName);
		EndIf;
		
		If Not CollectionProperties.NoData
		   AND Not ExtensionsObjects
		   AND StrFind(CollectionProperties.SingularName, "Register") = 0
		   AND StrFind(CollectionProperties.SingularName, "Constant") = 0 Then
			
			RefTypeName = CollectionProperties.SingularName + "Ref." + MetadataObject.Name;
			TypeDetails = New TypeDescription(RefTypeName);
			EmptyRefValue = TypeDetails.AdjustValue(Undefined);
		Else
			EmptyRefValue = Undefined;
		EndIf;
		
		NewRow = MetadataObjectProperties.Add();
		FillPropertyValues(NewRow, CollectionProperties);
		NewRow.Parent          = CollectionID(CollectionProperties.ID, ExtensionsObjects);
		NewRow.Description      = MetadataObjectPresentation(MetadataObject, CollectionProperties);
		NewRow.FullName         = FullName;
		NewRow.ParentFullName = ParentFullName;
		NewRow.Name               = MetadataObject.Name;
		
		NewRow.Synonym = ?(
			ValueIsFilled(MetadataObject.Synonym), MetadataObject.Synonym, MetadataObject.Name);
		
		NewRow.FullSynonym =
			ParentFullSynonym + CollectionProperties.SingularSynonym + ". " + NewRow.Synonym;
		
		NewRow.EmptyRefValue = EmptyRefValue;
		NewRow.MetadataObject     = MetadataObject;
		NewRow.ExtensionName        = ExtensionName;
		NewRow.ExtensionHashsum   = ExtensionHashsum;
		
		If CollectionProperties.Name = "Subsystems" Then
			AddMetadataObjectProperties(
				MetadataObject.Subsystems,
				CollectionProperties,
				MetadataObjectProperties,
				ExtensionsObjects,
				PredefinedItemNames,
				FullName,
				NewRow.FullSynonym + ". ");
		EndIf;
		PredefinedItemName = StrReplace(FullName, ".", "");
		If PredefinedItemNames.Get(PredefinedItemName) <> Undefined Then
			NewRow.PredefinedDataName = PredefinedItemName;
			PredefinedItemNames.Insert(PredefinedItemName, True);
		EndIf;
	EndDo;
	
EndProcedure

Function MetadataObjectPresentation(Val MetadataObject, Val CollectionProperties)
	
	Postfix = "(" + CollectionProperties.SingularSynonym + ")";
	
	Synonym = ?(ValueIsFilled(MetadataObject.Synonym), MetadataObject.Synonym, MetadataObject.Name);
	
	SynonymMaxLength = 150 - StrLen(Postfix);
	If StrLen(Synonym) > SynonymMaxLength + 1 Then
		Return Left(Synonym, SynonymMaxLength - 2) + "..." + Postfix;
	EndIf;
	
	Return Synonym + " (" + CollectionProperties.SingularSynonym + ")";
	
EndFunction

Function InsertQuestionMark(Val Row)
	
	If Not StrStartsWith(Row, "?") Then
		If Not StrStartsWith(Row, " ") Then
			Row = "? " + Row;
		Else
			Row = "?" + Row;
		EndIf;
	EndIf;
	
	Return Row;
	
EndFunction

Function UniqueFullName(Properties)
	
	FullName = InsertQuestionMark(Properties.FullName);
	
	If StrFind(FullName, "(") = 0 Then
		FullName = FullName + " (" + String(Properties.Ref.UUID())+ ")";
	EndIf;
	
	Return FullName;
	
EndFunction

Function MetadataFindByFullName(FullName)
	
	MetadataObject = Metadata.FindByFullName(FullName);
	
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	
	If Upper(MetadataObject.FullName()) <> Upper(FullName) Then
		
		If StrOccurrenceCount(Upper(FullName), Upper("Subsystem.")) > 1 Then
			Subsystem = FindSubsystemByFullName(FullName);
			If Subsystem = Undefined Then
				Return Undefined;
			EndIf;
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при поиске дочерней подсистемы по полному имени (при поиске ""%1"" была найдена ""%2"").
				           |Не следует называть подсистемы одинаково, либо использовать более новую версию платформы.'; 
				           |en = 'Cannot find a subordinate subsystem by full name (search for ""%1"" returned ""%2"").
				           |Please give different names to these subsystems, or upgrade to the latest platform version.'; 
				           |pl = 'Wystąpił błąd podczas wyszukiwania podsystemu podrzędnego według pełnej nazwy (podczas wyszukiwania ""%1"" znaleziono ""%2"").
				           |Nie podawaj podsystemom tych samych nazw, lub używaj najnowszej wersji platformy.';
				           |es_ES = 'Ha ocurrido un error durante la búsqueda de un subsistema secundario por un nombre completo (durante la búsqueda ""%1"" se ha encontrado ""%2"").
				           |No asignar a los subsistemas los mismo nombres, o utilizar la versión de la plataforma reciente.';
				           |es_CO = 'Ha ocurrido un error durante la búsqueda de un subsistema secundario por un nombre completo (durante la búsqueda ""%1"" se ha encontrado ""%2"").
				           |No asignar a los subsistemas los mismo nombres, o utilizar la versión de la plataforma reciente.';
				           |tr = 'Tali alt sistemi tam adıyla ararken bir hata oluştu (""%1"" ararken ""%2"" bulundu). 
				           |Alt sistemlere aynı adları vermeyin veya son platform sürümünü kullanmayın.';
				           |it = 'Non è possibile trovare un sistema subordinato attraverso il nome completo (ricerca per ""%1"" restituito ""%2"").
				           |Si prega di dare nomi differenti a questi sottosistemi, o aggiornali all''ultima versione della piattaforma.';
				           |de = 'Bei der Suche nach einem untergeordneten Subsystem mit einem vollständigen Namen ist ein Fehler aufgetreten (während die Suche nach ""%1"" wurde gefunden ""%2"").
				           |Geben Sie keinen Subsystemen die gleichen Namen oder verwenden Sie die aktuelle Plattformversion.'"),
				FullName,
				MetadataObject.FullName());
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при поиске объекта метаданных по полному имени (при поиске ""%1"" был найден ""%2"").'; en = 'Cannot find a metadata object by full name (search for ""%1"" returned ""%2"").'; pl = 'Wystąpił błąd podczas wyszukiwania obiektu metadanych według pełnej nazwy (szukano ""%1"", znaleziono ""%2"").';es_ES = 'Ha ocurrido un error al buscar un objeto de metadatos por el nombre completo (buscado ""%1"", ""%2"" se ha encontrado).';es_CO = 'Ha ocurrido un error al buscar un objeto de metadatos por el nombre completo (buscado ""%1"", ""%2"" se ha encontrado).';tr = 'Meta veri nesnesini tam adıyla ararken bir hata oluştu (""%1"" ararken ""%2"" bulundu).';it = 'Impossibile trovare un oggetto metadati secondo nome completo (cerca per ""%1"" restituito ""%2"").';de = 'Bei der Suche nach dem Metadatenobjekt nach dem vollständigen Namen ist ein Fehler aufgetreten (gesucht nach ""%1"", ""%2"" wurde gefunden).'"),
				FullName,
				MetadataObject.FullName());
		EndIf;
	EndIf;
	
	Return MetadataObject;
	
EndFunction

Function FindSubsystemByFullName(FullName, SubsystemCollection = Undefined)
	
	If SubsystemCollection = Undefined Then
		SubsystemCollection = Metadata.Subsystems;
	EndIf;
	
	SplitName = Mid(FullName, StrLen("Subsystem.") + 1);
	Position = StrFind(Upper(SplitName), Upper("Subsystem."));
	If Position > 0 Then
		SubsystemName = Left(SplitName, Position - 2);
		SplitName = Mid(FullName, Position + StrLen("Subsystem."));
	Else
		SubsystemName = SplitName;
		SplitName = Undefined;
	EndIf;
	
	FoundSubsystem = Undefined;
	For each Subsystem In SubsystemCollection Do
		If Upper(Subsystem.Name) = Upper(SubsystemName) Then
			FoundSubsystem = Subsystem;
			Break;
		EndIf;
	EndDo;
	
	If FoundSubsystem = Undefined Then
		Return Undefined;
	EndIf;
	
	If SplitName = Undefined Then
		Return FoundSubsystem;
	EndIf;
	
	Return FindSubsystemByFullName(SplitName, FoundSubsystem.Subsystems);
	
EndFunction

Function FullNameUsed(Object, ExtensionObjects)
	
	Query = New Query;
	Query.SetParameter("FullName", Object.FullName);
	Query.SetParameter("Ref",    Object.Ref);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.Ref <> &Ref
	|	AND MetadataObjectIDs.FullName = &FullName";
	ClarifyCatalogNameInQueryText(Query.Text, ExtensionObjects);
	
	Return NOT Query.Execute().IsEmpty();
	
EndFunction

Function IsCollection(Ref, ExtensionsObjects = False)
	
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	Return CollectionsProperties.Find(Ref.UUID(), "ID") <> Undefined;
	
EndFunction

Procedure PrepareNewSubsystemsListInMasterNode(DataExported)
	
	FoundDetails = DataExported.Find(Metadata.Subsystems.StandardSubsystems, "MetadataObject");
	If FoundDetails = Undefined Then
		Return;
	EndIf;
	StandardSubsystemsSubsystem = FoundDetails.Ref;
	
	Filter = New Structure;
	Filter.Insert("IsNew", True);
	Filter.Insert("Parent", StandardSubsystemsSubsystem);
	
	DetailsList = DataExported.FindRows(Filter);
	
	NewSubsystems = New Array;
	For Each Details In DetailsList Do
		NewSubsystems.Add(Details.FullName);
	EndDo;
	
	UpdateNewSubsystemsList(NewSubsystems);
	
EndProcedure

Procedure PrepareNewSubsystemsListInSubordinateNode(ObjectsToWrite)
	
	NewSubsystems = New Array;
	NameBeginning = "Subsystem.StandardSubsystems.";
	
	For Each Object In ObjectsToWrite Do
		If Not Object.IsNew()
		 Or Object.AdditionalProperties.Property("IsDuplicateReplacement")
		 Or Upper(Left(Object.FullName, StrLen(NameBeginning))) <> Upper(NameBeginning) Then
			Continue;
		EndIf;
		NewSubsystems.Add(Object.FullName);
	EndDo;
	
	UpdateNewSubsystemsList(NewSubsystems);
	
EndProcedure

Procedure UpdateNewSubsystemsList(NewSubsystems)
	
	Information = InfobaseUpdateInternal.InfobaseUpdateInfo();
	HasChanges = False;
	
	For Each SubsystemName In NewSubsystems Do
		If Information.NewSubsystems.Find(SubsystemName) = Undefined Then
			Information.NewSubsystems.Add(SubsystemName);
			HasChanges = True;
		EndIf;
	EndDo;
	
	// Removing the subsystem from the list of subsystems deleted from metadata.
	Index = Information.NewSubsystems.Count() - 1;
	While Index >= 0 Do
		SubsystemName = Information.NewSubsystems.Get(Index);
		If Metadata.FindByFullName(SubsystemName) = Undefined Then
			Information.NewSubsystems.Delete(Index);
			HasChanges = True;
		EndIf;
		Index = Index - 1;
	EndDo;
	
	If Not HasChanges Then
		Return;
	EndIf;
	
	InfobaseUpdateInternal.WriteInfobaseUpdateInfo(Information);
	
EndProcedure

Function CollectionID(UUID, ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return Catalogs.ExtensionObjectIDs.GetRef(UUID);
	Else
		Return GetRef(UUID);
	EndIf;
	
EndFunction

Function IsExtensionObject(ObjectOrRef)
	
	Return TypeOf(ObjectOrRef) = Type("CatalogObject.ExtensionObjectIDs")
		Or TypeOf(ObjectOrRef) = Type("CatalogRef.ExtensionObjectIDs");
	
EndFunction

Function CreateCatalogItem(ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return Catalogs.ExtensionObjectIDs.CreateItem();
	Else
		Return CreateItem();
	EndIf;
	
EndFunction

Function EmptyCatalogRef(ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return Catalogs.ExtensionObjectIDs.EmptyRef();
	Else
		Return EmptyRef();
	EndIf;
	
EndFunction

Function NewCatalogRef(ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return Catalogs.ExtensionObjectIDs.GetRef();
	Else
		Return GetRef();
	EndIf;
	
EndFunction

Function CatalogName(ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return "Catalog.ExtensionObjectIDs";
	Else
		Return "Catalog.MetadataObjectIDs";
	EndIf;
	
EndFunction

Function CatalogDescription(ExtensionsObjects)
	
	If ExtensionsObjects Then
		CatalogDescription = NStr("ru = 'Идентификаторы объектов расширений'; en = 'Extension object IDs'; pl = 'Identyfikatory obiektów rozszerzeń';es_ES = 'Identificadores de los objetos de extensiones';es_CO = 'Identificadores de los objetos de extensiones';tr = 'Meta veri nesne ID';it = 'IDs di oggetto dell''estensione';de = 'Identifikatoren von Erweiterungsobjekten'");
	Else
		CatalogDescription = NStr("ru = 'Идентификаторы объектов метаданных'; en = 'Metadata object IDs'; pl = 'Identyfikatory obiektów metadanych';es_ES = 'Identificadores del objeto de metadatos';es_CO = 'Identificadores del objeto de metadatos';tr = 'Meta veri nesne ID';it = 'ID oggetto metadati';de = 'Metadaten Objekt ID'");
	EndIf;
	
	Return CatalogDescription;
	
EndFunction

Procedure ClarifyCatalogNameInQueryText(QueryText, ExtensionsObjects)
	
	If ExtensionsObjects Then
		QueryText = StrReplace(QueryText, "Catalog.MetadataObjectIDs",
			CatalogName(ExtensionsObjects));
	EndIf;
	
EndProcedure

Procedure RaiseByError(ExtensionsObjects, ErrorText)
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Ошибка при работе со справочником ""%1"".'; en = '""%1"" catalog error.'; pl = '""%1"" błąd katalogu.';es_ES = 'Error al trabajar con el catálogo ""%1"".';es_CO = 'Error al trabajar con el catálogo ""%1"".';tr = '""%1"" katalog ile çalışırken bir hata oluştu.';it = '""%1"" errore anagrafica.';de = 'Fehler bei der Arbeit mit dem Verzeichnis ""%1"".'"),
		CatalogDescription(ExtensionsObjects));
	
	Raise ErrorTitle + Chars.LF + Chars.LF + ErrorText;
	
EndProcedure

Function IsSubsystem(MetadataObject, SubsystemsCollection = Undefined)
	
	If SubsystemsCollection = Undefined Then
		SubsystemsCollection = Metadata.Subsystems;
	EndIf;
	
	If SubsystemsCollection.Contains(MetadataObject) Then
		Return True;
	EndIf;
	
	For Each Subsystem In SubsystemsCollection Do
		If IsSubsystem(MetadataObject, Subsystem.Subsystems) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// For the AddRenaming procedure.
Function CollectionName(FullName)
	
	PointPosition = StrFind(FullName, ".");
	
	If PointPosition > 0 Then
		Return Left(FullName, PointPosition - 1);
	EndIf;
	
	Return "";
	
EndFunction

// This method is required by UpdateData and BeforeWriteObject procedures.
Procedure CheckObjectBeforeWrite(Object, AutoUpdate = False)
	
	ExtensionsObjects = IsExtensionObject(Object);
	
	If NOT AutoUpdate Then
		
		If Object.IsNew() Then
			
			RaiseByError(ExtensionsObjects,
				NStr("ru = 'Создание нового идентификатора объекта
				           |возможно только автоматически при обновлении данных справочника.'; 
				           |en = 'A new object ID can be created only automatically
				           |when updating catalog data.'; 
				           |pl = 'Możliwe jest automatyczne tworzenie nowego identyfikatora obiektu metadanych
				           |podczas aktualizacji danych katalogu.';
				           |es_ES = 'Es posible crear un nuevo identificados del objeto
				           |es posible solo automáticamente durante la actualización de los datos del catálogo.';
				           |es_CO = 'Es posible crear un nuevo identificados del objeto
				           |es posible solo automáticamente durante la actualización de los datos del catálogo.';
				           |tr = 'Yeni bir meta veri nesnesi 
				           |kimliğinin oluşturulması, yalnızca dizin verisi güncellenirken otomatik olarak mümkündür.';
				           |it = 'La creazione di un nuovo identificatore degli oggetti
				           |è possibile solo in modo automatico durante l''aggiornamento dei valori dell''elenco.';
				           |de = 'Das Erstellen einer neuen Objektkennung
				           |ist nur dann automatisch möglich, wenn Sie die Verzeichnisdaten aktualisieren.'"));
				
		ElsIf CannotChangeFullName(Object) Then
			
			RaiseByError(ExtensionsObjects, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'При изменении идентификатора объекта указано
				           |полное имя ""%1"", которое может быть
				           |установлено только автоматически при обновлении данных справочника.'; 
				           |en = 'Cannot set the full name ""%1""
				           |specified when changing the object ID.
				           |It can be set only automatically when updating catalog data.'; 
				           |pl = 'Podczas zmiany identyfikatora obiektu
				           | podano pełną nazwę ""%1"", która może być
				           |ustawiona tylko automatycznie podczas aktualizowania danych katalogu.';
				           |es_ES = 'Durante el cambio del identificador del objeto
				           |el nombre completo ""%1"" se ha especificado para el que
				           |se pueda configurar solo automáticamente durante la actualización de los datos del catálogo.';
				           |es_CO = 'Durante el cambio del identificador del objeto
				           |el nombre completo ""%1"" se ha especificado para el que
				           |se pueda configurar solo automáticamente durante la actualización de los datos del catálogo.';
				           |tr = 'Nesne kimliği%1 değiştirildiğinde, yalnızca 
				           |dizin verisi güncellendiğinde otomatik olarak ayarlanabilen "
" tam adı belirtilir.';
				           |it = 'Durante la modifica dell''identificatore dell''oggetto è specificato
				           |un nome completo ""%1"" che può essere impostato
				           |solamente in modo automatico durante l''aggiornamento dei valori dell''elenco.';
				           |de = 'Wenn Sie die Objektkennung ändern, wird der
				           |vollständige Name ""%1"" angegeben, der nur
				           |bei der Aktualisierung der Verzeichnisdaten automatisch gesetzt werden kann.'"),
				Object.FullName));
		Else
			If FullNameUsed(Object, False) Then
				CatalogDescription = CatalogDescription(False);
				
			ElsIf ExtensionsObjects AND FullNameUsed(Object, True) Then
				CatalogDescription = CatalogDescription(True);
			Else
				CatalogDescription = "";
			EndIf;
			If ValueIsFilled(CatalogDescription) Then
				RaiseByError(ExtensionsObjects, StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'При изменении идентификатора объекта указано
					           |полное имя ""%1"",
					           |которое уже используется в справочнике ""%2"".'; 
					           |en = 'Cannot set the full name ""%1""
					           |specified when changing the object ID.
					           |It is already in use in the ""%2"" catalog.'; 
					           |pl = 'Podczas zmiany identyfikatora obiektu wskazano
					           |pełną nazwę ""%1"",
					           |która jest już używana w katalogu ""%2"".';
					           |es_ES = 'Durante el cambio del identificador del objeto 
					           |el nombre completo está
					           |especificado ""%1"", que está utilizado en el catálogo ""%2"".';
					           |es_CO = 'Durante el cambio del identificador del objeto 
					           |el nombre completo está
					           |especificado ""%1"", que está utilizado en el catálogo ""%2"".';
					           |tr = 'Nesne 
					           |kimliği değiştirildiğinde, dizinde zaten 
					           |kullanılan ""%1"" tam adı belirtilir.%2';
					           |it = 'Durante la modifica dell''identificatore dell''oggetto è specificato
					           |un nome completo ""%1"", 
					           | che è già in uso nell''elenco ""%2"".';
					           |de = 'Beim Ändern der Objektkennung wird der
					           |vollständige Name ""%1"" angegeben,
					           |der bereits im Verzeichnis ""%2"" verwendet wird.'"),
					Object.FullName, CatalogDescription));
			EndIf;
		EndIf;
		
		UpdateIDProperties(Object);
	EndIf;
	
	If Not ExtensionsObjects AND Common.IsSubordinateDIBNode() Then
		
		If Object.IsNew()
		   AND Not IsCollection(Object.GetNewObjectRef(), IsExtensionObject(Object)) Then
			
			RaiseByError(ExtensionsObjects,
				NStr("ru = 'Добавление новых элементов может быть выполнено
				           |только в главном узле распределенной информационной базы.'; 
				           |en = 'Adding items is only allowed
				           |in the main node of the distributed infobase.'; 
				           |pl = 'Dodawanie elementów jest dozwolone tylko
				           |w głównym węźle rozproszonej dystrybucji bazy informacyjnej.';
				           |es_ES = 'Usted puede agregar nuevos elementos
				           |solo en el nodo principal de la infobase distribuida.';
				           |es_CO = 'Usted puede agregar nuevos elementos
				           |solo en el nodo principal de la infobase distribuida.';
				           |tr = 'Yeni öğeler, 
				           |sadece dağıtılan bilgi veritabanının ana ünitesinde eklenebilir.';
				           |it = 'L''aggiunta di nuovi elementi è possibile
				           |solamente nel nodo principale del database informatico suddiviso.';
				           |de = 'Das Hinzufügen neuer Elemente kann
				           |nur im Hauptknoten der verteilten Informationsbasis erfolgen.'"));
		EndIf;
		
		If Not Object.DeletionMark
		   AND Not IsCollection(Object.Ref, IsExtensionObject(Object)) Then
			
			If Upper(Object.FullName) <> Upper(Common.ObjectAttributeValue(Object.Ref, "FullName")) Then
				RaiseByError(ExtensionsObjects,
					NStr("ru = 'Изменение реквизита ""Полное имя"" может быть выполнено
					           |только в главном узле распределенной информационной базы.'; 
					           |en = 'The ""Full name"" attribute can be changed
					           |only in the main node of the distributed infobase.'; 
					           |pl = 'Atrybut ""Pełna nazwa"" może być zmieniany tylko
					           |w głównym węźle dystrybucji bazy informacyjnej.';
					           |es_ES = 'Es posible cambiar el atributo ""Nombre completo""
					           |solo en el nodo principal de la infobase distribuida.';
					           |es_CO = 'Es posible cambiar el atributo ""Nombre completo""
					           |solo en el nodo principal de la infobase distribuida.';
					           |tr = '""Tam
					           | ad"" niteliği sadece dağıtılan bilgi veritabanının ana ünitesinde değiştirilebilir.';
					           |it = 'La modifica del requisito ""Nome completo"" può essere effettuata
					           |solamente nel nodo principale del database informatico suddiviso.';
					           |de = 'Die Änderung des Attributs ""Vollständiger Name"" kann
					           |nur im Hauptknoten der verteilten Informationsbasis vorgenommen werden.'"));
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// This method is required by CheckForUsage and DataUpdated procedures.
Function ExtensionObjectsIDsUnvailableInSharedModeErrorDescription()
	
	Return
		NStr("ru = 'Справочник ""Идентификаторы объектов расширений""
		           |не может использоваться в неразделенном режиме.'; 
		           |en = 'Cannot use the ""Extension object IDs"" catalog
		           |in shared mode.'; 
		           |pl = 'Katalog ""Identyfikatory obiektów rozszerzeń""
		           |nie może być używany w trybie niepodzielnym.';
		           |es_ES = 'El catálogo ""Identificadores de los objetos de la extensión""
		           |no puede ser usado en el modo no distribuido.';
		           |es_CO = 'El catálogo ""Identificadores de los objetos de la extensión""
		           |no puede ser usado en el modo no distribuido.';
		           |tr = 'Uzantı nesne tanımlayıcıları 
		           |dizini bölünmemiş modda kullanılamaz.';
		           |it = 'L''elenco ""Identificatori degli oggetti delle estensioni"" 
		           |non può essere usato in modalità non condivisa.';
		           |de = 'Das Verzeichnis ""Identifikatoren von Erweiterungsobjekten""
		           |kann im ungeteilten Modus nicht verwendet werden.'");
	
EndFunction

// This method is required by OnCreateListFormAtServer procedure.
Procedure SetListOrderAndAppearance(Form)
	
	// Order.
	Order = Form.List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("DeletionMark");
	OrderItem.OrderType = DataCompositionSortDirection.Desc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("CollectionOrder");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Parent");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Synonym");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	// Conditional appearance.
	ConditionalAppearanceItem = Form.ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("List.FutureDeletionMark");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("Synonym");
	FieldAppearanceItem.Use = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("FullName");
	FieldAppearanceItem.Use = True;
	
EndProcedure

// This method is required by UpdateData procedure.
Function ExtensionNames(ExtensionSource)
	
	ExtensionNames = New Map;
	Extensions = ConfigurationExtensions.Get(, ExtensionSource);
	
	For Each Extension In Extensions Do
		ExtensionNames.Insert(Extension.Name, True);
	EndDo;
	
	Return ExtensionNames;
	
EndFunction

// This method is required by MetadataObjectIDByFullName and MetadataObjectIDs functions.
Function MetadataObjectIDsWithRetryAttempt(FullNamesOfMetadataObjects, ExcludeNonexistentItems, OneItem)
	
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True,
		Common.SeparatedDataUsageAvailable());
	
	Try
		IDs = MetadataObjectIDsWithoutRetryAttempt(
			FullNamesOfMetadataObjects, ExcludeNonexistentItems, OneItem);
	Except
		If Not Common.DataSeparationEnabled()
		 Or Not Common.SeparatedDataUsageAvailable() Then
			// If an error occurs and the catalog can be updated, updating the catalog and making an attempt to 
			// obtain the ID.
			IDs = Undefined;
		Else
			Raise;
		EndIf;
	EndTry;
	
	If IDs = Undefined Then
		UpdateCatalogData();
		IDs = MetadataObjectIDsWithoutRetryAttempt(
			FullNamesOfMetadataObjects, ExcludeNonexistentItems, OneItem);
	EndIf;
	
	Return IDs;
	
EndFunction

// This method is required by MetadataObjectIDs function.
Function MetadataObjectIDsWithoutRetryAttempt(FullNamesOfMetadataObjects, ExcludeNonexistentItems, OneItem)
	
	SetPrivilegedMode(True);
	
	ExtensionObjectIDsAvailable =
		ValueIsFilled(SessionParameters.AttachedExtensions)
		AND Common.SeparatedDataUsageAvailable();
	
	Query = New Query;
	Query.SetParameter("FullNames", FullNamesOfMetadataObjects);
	Query.Text =
	"SELECT
	|	IDs.Ref AS Ref,
	|	IDs.MetadataObjectKey,
	|	IDs.FullName
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	IDs.FullName IN (&FullNames)
	|	AND NOT IDs.DeletionMark";
	
	If ExtensionObjectIDsAvailable Then
		Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
		QueryText =
		"SELECT
		|	IDsVersions.ID AS Ref,
		|	IDs.MetadataObjectKey,
		|	IDsVersions.FullObjectName AS FullName
		|FROM
		|	InformationRegister.ExtensionVersionObjectIDs AS IDsVersions
		|		INNER JOIN Catalog.ExtensionObjectIDs AS IDs
		|		ON (IDs.Ref = IDsVersions.ID)
		|WHERE
		|	IDsVersions.ExtensionsVersion = &ExtensionsVersion
		|	AND IDsVersions.FullObjectName IN (&FullNames)";
		
		Query.Text = Query.Text + "
		|
		|UNION ALL
		|
		|" + QueryText;
	EndIf;
	
	DataExported = Query.Execute().Unload();
	DataExported.Indexes.Add("FullName");
	
	Errors = New Array;
	AddApplicationDeveloperParametersErrorClarification = False;
	
	IDsFromKeys = Undefined;
	
	Result = New Map;
	For Each FullMetadataObjectName In FullNamesOfMetadataObjects Do
		
		Filter = New Structure("FullName", FullMetadataObjectName);
		FoundRows = DataExported.FindRows(Filter);
		If FoundRows.Count() = 0 Then
			// One of the reasons why the ID is not found by the full name is that the full name is specified with an error.
			MetadataObject = Metadata.FindByFullName(FullMetadataObjectName);
			If MetadataObject = Undefined Then
				If ExcludeNonexistentItems Then
					Continue;
				EndIf;
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Объект метаданных не найден по полному имени:
					           |""%1"".'; 
					           |en = 'No metadata objects found by full name:
					           |""%1"".'; 
					           |pl = 'Nie znaleziono obiektów metadanych według pełnej nazwy:
					           |""%1"".';
					           |es_ES = 'Objeto de metadatos no encontrado por el nombre completo
					           |""%1"".';
					           |es_CO = 'Objeto de metadatos no encontrado por el nombre completo
					           |""%1"".';
					           |tr = 'Meta veri nesnesi tam adı ile bulunamadı: 
					           |%1';
					           |it = 'Nessun oggetto di metadati trovato per nome completo:
					           |""%1"".';
					           |de = 'Das Metadatenobjekt wurde nicht mit seinem vollständigen Namen gefunden:
					           |""%1"".'"),
					FullMetadataObjectName);
				Errors.Add(ErrorDescription);
				Continue;
			EndIf;
			
			If Not Metadata.Roles.Contains(MetadataObject)
			   AND Not Metadata.ExchangePlans.Contains(MetadataObject)
			   AND Not Metadata.Constants.Contains(MetadataObject)
			   AND Not Metadata.Catalogs.Contains(MetadataObject)
			   AND Not Metadata.Documents.Contains(MetadataObject)
			   AND Not Metadata.DocumentJournals.Contains(MetadataObject)
			   AND Not Metadata.Reports.Contains(MetadataObject)
			   AND Not Metadata.DataProcessors.Contains(MetadataObject)
			   AND Not Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject)
			   AND Not Metadata.ChartsOfAccounts.Contains(MetadataObject)
			   AND Not Metadata.ChartsOfCalculationTypes.Contains(MetadataObject)
			   AND Not Metadata.InformationRegisters.Contains(MetadataObject)
			   AND Not Metadata.AccumulationRegisters.Contains(MetadataObject)
			   AND Not Metadata.AccountingRegisters.Contains(MetadataObject)
			   AND Not Metadata.CalculationRegisters.Contains(MetadataObject)
			   AND Not Metadata.BusinessProcesses.Contains(MetadataObject)
			   AND Not Metadata.Tasks.Contains(MetadataObject)
			   AND Not IsSubsystem(MetadataObject) Then
				
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Объект метаданных не поддерживается:
					           |""%1"".
					           |
					           |Допустимы только типы объектов метаданных перечисленные в комментарии к функции.'; 
					           |en = 'The metadata object is not supported:
					           |""%1"".
					           |
					           |Only the metadata object types listed in the comments to the function are allowed.'; 
					           |pl = 'Obiekt metadanych nie jest obsługiwany:
					           |""%1"".
					           |
					           |Są dozwolone tylko typy obiektów metadanych wymienione w komentarzu do funkcji.';
					           |es_ES = 'El objeto de metadatos no se admite:
					           |""%1"".
					           |
					           |Se admiten solo los tipos de objetos de metadatos renombrados en el comentario de la función.';
					           |es_CO = 'El objeto de metadatos no se admite:
					           |""%1"".
					           |
					           |Se admiten solo los tipos de objetos de metadatos renombrados en el comentario de la función.';
					           |tr = 'Meta veri nesnesi desteklenmiyor: %1"
". 
					           |
					           |Yalnızca işlev yorumunda listelenen meta veri nesne türleri kabul edilebilir.';
					           |it = 'L''oggetto metadati non è supportato:
					           |""%1"".
					           |
					           |Sono ammessi solo i tipi degli oggetti dei metadati elencati nel commento della funzione.';
					           |de = 'Das Metadatenobjekt wird nicht unterstützt:
					           |""%1"".
					           |
					           |Es sind nur die im Funktionskommentar aufgeführten Typen von Metadatenobjekten erlaubt.'"),
					FullMetadataObjectName);
				Errors.Add(ErrorDescription);
				Continue;
			EndIf;
			
			Extension = MetadataObject.ConfigurationExtension();
			If Extension <> Undefined
			   AND Not Common.SeparatedDataUsageAvailable() Then
			
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Идентификаторы объектов метаданных расширений не поддерживаются в неразделенном режиме.
					           |Невозможно вернуть идентификатор объекта метаданных ""%1""
					           |расширения ""%2"" версии ""%3"".'; 
					           |en = 'Extension metadata object IDs are not supported in shared mode.
					           |Cannot return the ID of metadata object ""%1""
					           |in extension ""%2"" version %3.'; 
					           |pl = 'Identyfikatory obiektów metadanych rozszerzeń nie są obsługiwane w trybie niepodzielonym.
					           |Nie można zwrócić identyfikator obiektu metadanych ""%1""
					           |rozszerzenia ""%2"" wersji ""%3"".';
					           |es_ES = 'Los identificadores de los objetos de metadatos de las extensiones no se admiten en el modo no distribuido.
					           |Es imposible devolver el identificador del objeto de metadatos ""%1""
					           | de la extensión ""%2"" de la versión ""%3"".';
					           |es_CO = 'Los identificadores de los objetos de metadatos de las extensiones no se admiten en el modo no distribuido.
					           |Es imposible devolver el identificador del objeto de metadatos ""%1""
					           | de la extensión ""%2"" de la versión ""%3"".';
					           |tr = 'Uzantı meta veri nesne tanımlayıcıları bölünmemiş modda desteklenmez. 
					           |""%2"" Sürümün "
" metaveri uzantı nesne tanımlayıcısı ""%1"" geri yüklenemez. %3';
					           |it = 'Gli identificatori degli oggetti dei metadati non sono supportati nel regime non condiviso.
					           |Impossibile ritornare l''identificatore dell''oggetto dei metadati ""%1"" 
					           | con estensione ""%2"" e versione ""%3"".';
					           |de = 'Identifikatoren von Erweiterungs-Metadatenobjekten werden im ungeteilten Modus nicht unterstützt.
					           |Es ist nicht möglich, die Metadaten-Objektkennung ""%1""
					           |Erweiterung ""%2"" Version ""%3"" zurückzugeben.'"),
					FullMetadataObjectName, Extension.Name, Extension.Version);
				Errors.Add(ErrorDescription);
				Continue;
			EndIf;
			
			If StandardSubsystemsServer.ApplicationVersionUpdatedDynamically() Then
				If IDsFromKeys = Undefined Then
					IDsFromKeys = IDsFromKeys();
				EndIf;
				ID = IDsFromKeys.Get(FullMetadataObjectName);
				If ID = Undefined Then
					StandardSubsystemsServer.RequireRestartDueToApplicationVersionDynamicUpdate();
				EndIf;
				Result.Insert(FullMetadataObjectName, ID);
				Continue;
			EndIf;
			
			ErrorTemplate = ?(Extension <> Undefined,
				NStr("ru = 'Для объекта метаданных ""%1""
				           |не найден идентификатор в регистре сведений ""Идентификаторы объектов версий расширений"".'; 
				           |en = 'For metadata object ""%1"",
				           |no IDs are found in the ""Extension version object IDs"" information register.'; 
				           |pl = 'W przypadku obiektu metadanych ""%1"",
				           |nie ma identyfikatorów w rejestrze informacji „Identyfikatory obiektu wersji rozszerzenia”.';
				           |es_ES = 'Para el objeto de metadatos ""%1""
				           | no se ha encontrado el identificador en el registro de información ""Identificadores de los objetos de las versiones de las extensiones"".';
				           |es_CO = 'Para el objeto de metadatos ""%1""
				           | no se ha encontrado el identificador en el registro de información ""Identificadores de los objetos de las versiones de las extensiones"".';
				           |tr = 'Meta veri nesnesi için ""%1"" uzantı sürüm nesne tanımlayıcıları ""
				           |kayıt bilgileri kimliği bulunamadı.';
				           |it = 'Per l''oggetto di metadati ""%1""
				           | non esiste ID nel registro informazioni ""ID degli oggetti delle versioni di estensioni"".';
				           |de = 'Die Kennung für das Metadatenobjekt""%1""
				           |wurde im Datenregister ""Kennungen von Objekten der Erweiterungsversion"" nicht gefunden.'"),
				NStr("ru = 'Для объекта метаданных ""%1""
				           |не найден идентификатор в справочнике ""Идентификаторы объектов метаданных"".'; 
				           |en = 'The metadata object ID ""%1""
				           |is not found in the ""Metadata object IDs"" catalog.'; 
				           |pl = 'Dla obiektu metadanych ""%1""
				           |nie znaleziono identyfikatora w katalogu ""Identyfikatory obiektów metadanych"".';
				           |es_ES = 'Para el objeto de metadatos ""%1""
				           |no se ha encontrado identificador en el catálogo ""Identificadores de los objetos de metadatos"".';
				           |es_CO = 'Para el objeto de metadatos ""%1""
				           |no se ha encontrado identificador en el catálogo ""Identificadores de los objetos de metadatos"".';
				           |tr = 'Meta veri nesnesi için ""%1""
				           | Meta veri nesne tanımlayıcıları"" dizininde bir tanımlayıcı bulunamadı.';
				           |it = 'L''ID dell''oggetto di metadati ""%1""
				           |non è stato trovato nel catalogo ""ID oggetti di metadati"".';
				           |de = 'Für das Metadatenobjekt ""%1""
				           |wird die Kennung nicht im Verzeichnis ""Metadaten Objekt ID"" gefunden.'"));
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, FullMetadataObjectName);
			AddApplicationDeveloperParametersErrorClarification = True;
			Errors.Add(ErrorDescription);
			Continue;
			
		ElsIf FoundRows.Count() > 1 Then
			
			ErrorTemplate = ?(ExtensionObjectIDsAvailable,
				NStr("ru = 'Для объекта метаданных ""%1""
				           |найдено несколько идентификаторов в справочнике ""Идентификаторы объектов метаданных"" и
				           |регистре сведений ""Идентификаторы объектов версий расширений"".'; 
				           |en = 'For metadata object ""%1"",
				           |multiple IDs are found in the ""Metadata object IDs"" catalog
				           |and the ""Extension version object IDs"" information register.'; 
				           |pl = 'W przypadku obiektu metadanych ""%1"",
				           |wiele identyfikatorów znajduje się w katalogu ""Identyfikatory obiektu metadanych""
				           |i rejestrze informacji ""Identyfikatory obiektu wersji rozszerzonej"".';
				           |es_ES = 'Para el objeto de metadatos ""%1""
				           |se ha encontrado unos identficadores en el catálogo ""Identificadores de los objetos de metadatos"" y
				           |en el registro de información ""Identificadores de los objetos de las versiones de las extensiones"".';
				           |es_CO = 'Para el objeto de metadatos ""%1""
				           |se ha encontrado unos identficadores en el catálogo ""Identificadores de los objetos de metadatos"" y
				           |en el registro de información ""Identificadores de los objetos de las versiones de las extensiones"".';
				           |tr = 'Meta veri nesnesi için ""%1""
				           |meta veri nesne tanımlayıcıları""ve ""
				           |uzantı sürüm nesne tanımlayıcıları"" kayıt bilgileri başvurusu birden çok tanımlayıcı bulundu.';
				           |it = 'Per l''oggetto dei metadati ""%1"" 
				           |sono stati trovati alcuni identificatori nell''elenco ""Identificatori degli oggetti dei metadati"" e
				           |nel registro delle informazioni ""Identificatori degli oggetti delle versioni delle estensioni"".';
				           |de = 'Für das Metadatenobjekt ""%1""
				           |wurden im Verzeichnis ""Metadaten Objekt ID"" und im
				           |Datenregister ""Identifikatoren von Objekten der Erweiterungsversionen"" mehrere Kennungen gefunden.'"),
				NStr("ru = 'Для объекта метаданных ""%1""
				           |найдено несколько идентификаторов в справочнике ""Идентификаторы объектов метаданных"".'; 
				           |en = 'For metadata object ""%1"",
				           |multiple IDs are found in the ""Metadata object IDs"" catalog.'; 
				           |pl = 'W przypadku obiektu metadanych ""%1"",
				           |wiele identyfikatorów znajduje się w katalogu ""Identyfikatory obiektu metadanych"".';
				           |es_ES = 'Para el objeto de metadatos ""%1""
				           |se ha encontrado unos identificadores en el catálogo ""Identificadores de los objetos de metadatos"".';
				           |es_CO = 'Para el objeto de metadatos ""%1""
				           |se ha encontrado unos identificadores en el catálogo ""Identificadores de los objetos de metadatos"".';
				           |tr = 'Meta veri nesnesi için ""%1""
				           | Meta veri nesne tanımlayıcıları"" dizininde birkaç tanımlayıcı bulundu.';
				           |it = 'Per l''oggetto dei metadati ""%1"" 
				           | sono stati trovati alcuni identificatori nell''elenco ""Identificatori degli oggetti dei metadati"".';
				           |de = 'Für das Metadatenobjekt ""%1""
				           |wurden mehrere Kennungen im Verzeichnis ""Metadaten Objekt ID"" gefunden.'"));
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, FullMetadataObjectName);
			AddApplicationDeveloperParametersErrorClarification = True;
			Errors.Add(ErrorDescription);
			Continue;
			
		EndIf;
		
		// Checking whether the metadata object key matches the metadata object full name.
		TableRow = FoundRows[0];
		CheckResult = MetadataObjectKeyMatchesFullName(TableRow);
		If CheckResult.NotCorresponds Then
			CatalogDescription = CatalogDescription(IsExtensionObject(TableRow.Ref));
			
			If CheckResult.MetadataObject = Undefined Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Для объекта метаданных ""%1""
					           |найден идентификатор в справочнике ""%2"",
					           |которому соответствует удаленный объект метаданных.'; 
					           |en = 'For metadata object ""%1"",
					           |an ID matching a deleted metadata object 
					           |is found in the ""%2"" catalog.'; 
					           |pl = 'W przypadku obiektu metadanych ""%1"",
					           |identyfikator pasujący do usuniętego obiektu metadanych 
					           |znajduje się w katalogu ""%2"".';
					           |es_ES = 'Para el objeto de metadatos ""%1""
					           |se ha encontrado un identificador en el catálogo ""%2""
					           |al que corresponde un objeto eliminado de metadatos.';
					           |es_CO = 'Para el objeto de metadatos ""%1""
					           |se ha encontrado un identificador en el catálogo ""%2""
					           |al que corresponde un objeto eliminado de metadatos.';
					           |tr = 'Meta veri nesnesi için ""%1""
					           | uzak meta veri nesnesine karşılık gelen ""%2"" 
					           |başvurusu kimliği bulundu.';
					           |it = 'Per l''oggetto dei metadati ""%1"" 
					           | è stato trovato un identificatore nell''elenco ""%2"" 
					           | al quale corrisponde un oggetto dei metadati cancellato.';
					           |de = 'Für das Metadatenobjekt ""%1""
					           |wird die Kennung im Verzeichnis ""%2"" gefunden,
					           |das dem entfernten Metadatenobjekt entspricht.'"),
					FullMetadataObjectName, CatalogDescription);
			Else
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Для объекта метаданных ""%1""
					           |найден идентификатор в справочнике ""%2"",
					           |который соответствует другому объекту метаданных ""%3"".'; 
					           |en = 'For metadata object ""%1"",
					           |an ID matching another metadata object ""%3""
					           |is found in the ""%2"" catalog.'; 
					           |pl = 'W przypadku obiektu metadanych ""%1"",
					           |identyfikator pasujący do usuniętego obiektu metadanych ""%3""
					           |znajduje się w katalogu ""%2"".';
					           |es_ES = 'Para el objeto de metadatos ""%1""
					           |se ha encontrado un identificador en el catálogo ""%2""
					           |que corresponde a otro objeto de metadatos ""%3"".';
					           |es_CO = 'Para el objeto de metadatos ""%1""
					           |se ha encontrado un identificador en el catálogo ""%2""
					           |que corresponde a otro objeto de metadatos ""%3"".';
					           |tr = 'Meta veri nesnesi için ""%1""
					           | başka uzak meta veri nesnesine karşılık gelen ""%2"" 
					           |başvurusu kimliği bulundu.%3';
					           |it = 'Per l''oggetto dei metadati ""%1""
					           | è stato trovato un identificatore nell''elenco ""%2""
					           | al quale corrisponde un altro oggetto dei metadati ""%3"".';
					           |de = 'Für das Metadatenobjekt ""%1""
					           |befindet sich die Kennung im Verzeichnis ""%2"",
					           |was einem anderen Metadatenobjekt ""%3"" entspricht.'"),
					FullMetadataObjectName, CatalogDescription, CheckResult.MetadataObject);
			EndIf;
			
			AddApplicationDeveloperParametersErrorClarification = True;
			Errors.Add(ErrorDescription);
			Continue;
		EndIf;
		
		Result.Insert(FullMetadataObjectName, TableRow.Ref);
	EndDo;
	
	ErrorsCount = Errors.Count();
	If ErrorsCount > 0 Then
		
		If OneItem Then
			ErrorTitle = NStr("ru = 'Ошибка при выполнении функции Common.MetadataObjectID().'; en = 'Common.MetadataObjectID() function error.'; pl = 'Common.MetadataObjectID() błąd funkcji';es_ES = 'Error al ejecutar la función Common.MetadataObjectID().';es_CO = 'Error al ejecutar la función Common.MetadataObjectID().';tr = 'Common.MetadataObjectID() işlevi esnasında hata oluştu.';it = 'Errore funzione Common.MetadataObjectID().';de = 'Fehler bei der Ausführung der Funktion Common.MetadataObjectID().'");
			
		ElsIf ErrorsCount = 1 Then
			ErrorTitle = NStr("ru = 'Ошибка при выполнении функции Common.MetadataObjectIDs().'; en = 'Common.MetadataObjectIDs() function error.'; pl = 'Common.MetadataObjectIDs() błąd funkcji';es_ES = 'Error al ejecutar la función Common.MetadataObjectIDs().';es_CO = 'Error al ejecutar la función Common.MetadataObjectIDs().';tr = 'Common.MetadataObjectIDs() işlevi esnasında hata oluştu.';it = 'Errore funzione Common.MetadataObjectIDs().';de = 'Fehler bei der Ausführung der Funktion Allgemeine Common.MetadataObjectIDs().'");
		Else
			ErrorTitle = NStr("ru = 'Ошибки при выполнении функции Common.MetadataObjectIDs().'; en = 'Common.MetadataObjectIDs() function errors.'; pl = 'Common.MetadataObjectIDs() błąd funkcji';es_ES = 'Error al ejecutar la función Common.MetadataObjectIDs().';es_CO = 'Error al ejecutar la función Common.MetadataObjectIDs().';tr = 'Common.MetadataObjectIDs() işlevi esnasında hatalar oluştu.';it = 'Errori funzione Common.MetadataObjectIDs().';de = 'Fehler bei der Ausführung der Funktion Allgemeine Common.MetadataObjectIDs().'");
		EndIf;
		
		Separator = Chars.LF + Chars.LF;
		AllErrorsText = "";
		ErrorNumber = 0;
		For Each ErrorDescription In Errors Do
			ErrorNumber = ErrorNumber + 1;
			AllErrorsText = AllErrorsText + ?(ErrorNumber = 1, "", Separator) + ErrorDescription;
			If ErrorNumber = 3 AND ErrorsCount > 5 Then
				CountPresentation = StringFunctionsClientServer.StringWithNumberForAnyLanguage(
					NStr("ru = ';%1 ошибка;;%1 ошибки;%1 ошибок;%1 ошибки'; en = ';%1 error;; %1 errors; %1 errors; %1 errors'; pl = ';%1 błąd;; %1 błędy; %1 błędów; %1 błędu';es_ES = ';%1 error;; %1 del error; %1 de los errores; %1 del error';es_CO = ';%1 error;; %1 del error; %1 de los errores; %1 del error';tr = ';%1 hata;; %1 hata; %1 hata; %1 hata';it = ';%1 errore;; %1 errori; %1 errori; %1 errori';de = ';%1 Fehler;; %1 Fehler; %1 Fehler; %1 Fehler'"), (ErrorsCount - ErrorNumber));
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '... И еще %1'; en = '... plus %1'; pl = '... I jeszcze %1';es_ES = '... Y más %1';es_CO = '... Y más %1';tr = '... Daha fazla %1';it = '... più %1';de = '... und außerdem %1'"),
					CountPresentation);
				AllErrorsText = AllErrorsText + Separator + ErrorDescription;
				Break;
			EndIf;
		EndDo;
		
		AllErrorsText = AllErrorsText + ?(AddApplicationDeveloperParametersErrorClarification,
			StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper(), "");
		
		Raise ErrorTitle + Separator + AllErrorsText;
	EndIf;
	
	Return Result;
	
EndFunction

// This method is required by MetadataObjectIDsWithoutRetryAttempt function.
Function IDsFromKeys()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref AS Ref,
	|	IDs.MetadataObjectKey AS KeyStorage
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs";
	
	Selection = Query.Execute().Select();
	
	IDsFromKeys = New Map;
	
	While Selection.Next() Do
		If TypeOf(Selection.KeyStorage) <> Type("ValueStorage") Then
			Continue;
		EndIf;
		MetadataObjectKey = Selection.KeyStorage.Get();
		
		If MetadataObjectKey = Undefined
		 Or MetadataObjectKey = Type("Undefined") Then
			Continue;
		EndIf;
		
		MetadataObject = MetadataObjectByKey(MetadataObjectKey);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		
		FullName = MetadataObject.FullName();
		If IDsFromKeys.Get(FullName) <> Undefined Then
			StandardSubsystemsServer.RequireRestartDueToApplicationVersionDynamicUpdate();
		EndIf;
		
		IDsFromKeys.Insert(FullName, Selection.Ref);
	EndDo;
	
	Return IDsFromKeys;
	
EndFunction

// This method is required by MetadataObjectByID and MetadataObjectsByIDs functions.
Function MetadataObjectsByIDsWithRetryAttempt(IDs, ExceptNonexistentAndUnavailableItems)
	
	If IDs.Count() = 0 Then
		Return New Map;
	EndIf;
	
	ConfigurationIDs = New Array;
	ExtensionsIDs   = New Array;
	
	AddedConfigurationIDs = New Map;
	AddedExtensionsIDs   = New Map;
	
	For Each CurrentID In IDs Do
		If TypeOf(CurrentID) = Type("CatalogRef.MetadataObjectIDs") Then
			If AddedConfigurationIDs[CurrentID] = Undefined Then
				ConfigurationIDs.Add(CurrentID);
				AddedConfigurationIDs.Insert(CurrentID, True);
			EndIf;
		ElsIf TypeOf(CurrentID) = Type("CatalogRef.ExtensionObjectIDs") Then
			If AddedExtensionsIDs[CurrentID] = Undefined Then
				ExtensionsIDs.Add(CurrentID);
				AddedExtensionsIDs.Insert(CurrentID, True);
			EndIf;
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка при выполнении функции Common.MetadataObjectByID().
				           |
				           |Неверный тип идентификатора объекта метаданных:
				           |""%1"".'; 
				           |en = 'Common.MetadataObjectByID() function error.
				           |
				           |Invalid metadata object ID type:
				           |""%1"".'; 
				           |pl = 'Błąd podczas wykonywania funkcji Common.MetadataObjectByID().
				           |
				           |Nieprawidłowy typ identyfikatora obiektu metadanych:
				           |""%1""';
				           |es_ES = 'Error al ejecutar la función Common.MetadataObjectByID().
				           |
				           |Tipo incorrecto del identificador del objeto de metadatos:
				           |""%1"".';
				           |es_CO = 'Error al ejecutar la función Common.MetadataObjectByID().
				           |
				           |Tipo incorrecto del identificador del objeto de metadatos:
				           |""%1"".';
				           |tr = 'Common.MetadataObjectByID() işlevi esnasında bir hata oluştu. 
				           |
				           | Metaveri nesne tanımlayıcısının türü yanlıştır: 
				           |""%1"".';
				           |it = 'Errore durante l''esecuzione della funzione ScopoGenerale.OggettoMetadatiSecondoIdentificatore().
				           |
				           |Tipo incorretto dell''identificatore dell''oggetto dei metadati:
				           |""%1"".';
				           |de = 'Fehler bei der Ausführung der Funktion Common.MetadataObjectByID().
				           |
				           |Falscher Typ der Metadaten-Objektkennung:
				           |""%1"".'"),
				TypeOf(CurrentID));
		EndIf;
	EndDo;
	
	If ConfigurationIDs.Count() > 0 Then
		StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True, False);
	EndIf;
	
	If ExtensionsIDs.Count() > 0 Then
		StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True, True);
	EndIf;
	
	Try
		MetadataObjects = MetadataObjectsByIDsWithoutRetryAttempt(IDs,
			ConfigurationIDs, ExtensionsIDs, ExceptNonexistentAndUnavailableItems);
	Except
		If Not Common.DataSeparationEnabled()
		 Or Not Common.SeparatedDataUsageAvailable() Then
			// If an error occurs and the catalog can be updated, updating the catalog and making an attempt to 
			// obtain the ID.
			MetadataObjects = Undefined;
		Else
			Raise;
		EndIf;
	EndTry;
	
	If MetadataObjects = Undefined Then
		UpdateCatalogData();
		MetadataObjects = MetadataObjectsByIDsWithoutRetryAttempt(IDs,
			ConfigurationIDs, ExtensionsIDs, ExceptNonexistentAndUnavailableItems);
	EndIf;
	
	Return MetadataObjects;
	
EndFunction

// This method is required by MetadataObjectsByIDsWithRetryAttempt function.
Function MetadataObjectsByIDsWithoutRetryAttempt(IDs,
			ConfigurationIDs, ExtensionsIDs, ExceptNonexistentAndUnavailableItems)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	If ConfigurationIDs.Count() > 0 Then
		Query.SetParameter("ConfigurationIDs", ConfigurationIDs);
		Query.Text =
		"SELECT
		|	IDs.Ref AS Ref,
		|	IDs.MetadataObjectKey AS MetadataObjectKey,
		|	IDs.FullName AS FullName,
		|	IDs.DeletionMark AS DeletionMark,
		|	FALSE AS ExtensionObject,
		|	"""" AS ExtensionName
		|FROM
		|	Catalog.MetadataObjectIDs AS IDs
		|WHERE
		|	IDs.Ref IN(&ConfigurationIDs)";
	EndIf;
	
	If ExtensionsIDs.Count() > 0 Then
		Query.SetParameter("ExtensionsIDs", ExtensionsIDs);
		Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
		If ValueIsFilled(Query.Text) Then
			Query.Text = Query.Text +
			"
			|
			|UNION ALL
			|
			|";
		EndIf;
		Query.Text = Query.Text +
		"SELECT
		|	IDs.Ref AS Ref,
		|	IDs.MetadataObjectKey AS MetadataObjectKey,
		|	ISNULL(IDsVersions.FullObjectName, """") AS FullName,
		|	IDs.DeletionMark AS DeletionMark,
		|	TRUE AS ExtensionObject,
		|	IDs.ExtensionName AS ExtensionName
		|FROM
		|	Catalog.ExtensionObjectIDs AS IDs
		|		LEFT JOIN InformationRegister.ExtensionVersionObjectIDs AS IDsVersions
		|		ON (IDsVersions.ID = IDs.Ref)
		|WHERE
		|	IDsVersions.ExtensionsVersion = &ExtensionsVersion
		|	AND IDs.Ref IN(&ExtensionsIDs)";
	EndIf;
	
	DataExported = Query.Execute().Unload();
	ErrorTitle = NStr("ru = 'Ошибка при выполнении функции Common.MetadataObjectByID().'; en = 'Common.MetadataObjectByID() function error.'; pl = 'Common.MetadataObjectByID() błąd funkcji';es_ES = 'Error al ejecutar la función Common.MetadataObjectByID().';es_CO = 'Error al ejecutar la función Common.MetadataObjectByID().';tr = 'Common.MetadataObjectByID() işlevi esnasında hata oluştu.';it = 'Errore funzione Common.MetadataObjectByID().';de = 'Fehler bei der Ausführung der Funktion Common.MetadataObjectByID().'");
	
	IDsMetadataObjects = New Map;
	
	TotalIDs = ConfigurationIDs.Count() + ExtensionsIDs.Count();
	If DataExported.Count() < TotalIDs Then
		For Each ID In IDs Do
			If DataExported.Find(ID, "Ref") = Undefined Then
				If ExceptNonexistentAndUnavailableItems Then
					// The metadata object does not exist.
					IDsMetadataObjects.Insert(ID, Null);
					Continue;
				Else
					Break;
				EndIf;
			EndIf;
		EndDo;
		If Not ExceptNonexistentAndUnavailableItems Then
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Идентификатор ""%1""
				           |не найден в справочнике ""%2"".'; 
				           |en = 'The ID ""%1""
				           |is not found in catalog ""%2"".'; 
				           |pl = 'Identyfikatora ""%1""
				           |nie znaleziono w katalogu ""%2"".';
				           |es_ES = 'El identificador ""%1""
				           |no se ha encontrado en el catálogo ""%2"".';
				           |es_CO = 'El identificador ""%1""
				           |no se ha encontrado en el catálogo ""%2"".';
				           |tr = '""%1"" kimliği
				           |""%2"" kataloğunda bulunamadı.';
				           |it = 'ID ""%1""
				           |non trovata nel catalogo ""%2"".';
				           |de = 'Die Kennung ""%1""
				           |wird nicht im Verzeichnis ""%2"" gefunden.'"),
				String(ID),
				CatalogDescription(ExtensionsIDs.Find(ID) <> Undefined));
			
			Raise ErrorTitle + Chars.LF + Chars.LF + ErrorDescription
				+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper();
		EndIf;
	EndIf;
	
	ApplicationVersionUpdatedDynamically = StandardSubsystemsServer.ApplicationVersionUpdatedDynamically();
	
	// Checking whether the metadata object key matches the metadata object full name.
	For Each Properties In DataExported Do
		CheckResult = MetadataObjectKeyMatchesFullName(Properties);
		If CheckResult.NotCorresponds Then
			
			If CheckResult.MetadataObject = Undefined Then
				
				If Properties.ExtensionObject AND Not Properties.DeletionMark Then
					// Attaching the extension might have failed.
					If ExceptNonexistentAndUnavailableItems Then
						IDsMetadataObjects.Insert(Properties.Ref, Undefined);
						Continue;
					Else
						Filter = New Structure("Name", Properties.ExtensionName);
						If ConfigurationExtensions.Get(Filter, ConfigurationExtensionsSource.SessionDisabled).Count() > 0 Then
							Raise StringFunctionsClientServer.SubstituteParametersToString(
								NStr("ru = 'Расширение конфигурации %1 установлено, но отключено при запуске сеанса.
								           |Обычно, это значит, что при подключении расширения конфигурации возникла ошибка.'; 
								           |en = 'Configuration extension %1 is installed but detached at the start of the session.
								           |Usually it means that an error occurred when attaching a configuration extension.'; 
								           |pl = 'Rozszerzenie konfiguracji %1 jest zainstalowane ale zostało ono wyłączone podczas uruchamiania sesji.
								           |Zwykle oznacza to, że przy podłączeniu rozszerzenia konfiguracji zaistniał błąd.';
								           |es_ES = 'La extensión de la configuración %1 se ha instalado, pero ha sido desactivada al lanzar la sesión.
								           |Normalmente esto significa que ha ocurrido un error al conectar la extensión de la configuración.';
								           |es_CO = 'La extensión de la configuración %1 se ha instalado, pero ha sido desactivada al lanzar la sesión.
								           |Normalmente esto significa que ha ocurrido un error al conectar la extensión de la configuración.';
								           |tr = 'Yapılandırma uzantısı %1yüklendi, ancak oturum başladığında devre dışı bırakıldı. 
								           |Genellikle, bu yapılandırma uzantısı bağlandığında bir hata oluştu anlamına gelir.';
								           |it = 'L''estensione di configurazione %1 è installata ma scollegata all''inizio della sessione.
								           |Di solito, indica il verificarsi di un errore durante il collegamento all''estensione di configurazione.';
								           |de = 'Die Konfigurationserweiterung %1 ist eingestellt, aber beim Start der Sitzung deaktiviert.
								           |In der Regel bedeutet dies, dass beim Anschluss der Konfigurationserweiterung ein Fehler aufgetreten ist.'"),
								Properties.ExtensionName);
						Else
							Raise StringFunctionsClientServer.SubstituteParametersToString(
								NStr("ru = 'Расширение конфигурации %1 установлено, но не подключено.
								           |Требуется перезапустить сеанс.'; 
								           |en = 'Configuration extension %1 is installed but not attached.
								           |Please restart the session.'; 
								           |pl = 'Rozszerzenie konfiguracji %1 jest zainstalowane ale nie jest włączone.
								           |Należy zrestartować sesję.';
								           |es_ES = 'La extensión de la configuración %1 se ha instalado pero no conectado. 
								           |Se requiere reiniciar la sesión.';
								           |es_CO = 'La extensión de la configuración %1 se ha instalado pero no conectado. 
								           |Se requiere reiniciar la sesión.';
								           |tr = 'Yapılandırma uzantısı %1yüklendi, ancak bağlanamadı. 
								           |Oturum yeniden başlatılmalıdır.';
								           |it = 'Estensione di configurazione %1 installata ma non collegata.
								           |Riavviare la sessione.';
								           |de = 'Die Konfigurationserweiterung %1 ist installiert, aber nicht verbunden.
								           |Die Sitzung muss neu gestartet werden.'"),
								Properties.ExtensionName);
						EndIf;
					EndIf;
					
				ElsIf Not Properties.ExtensionObject AND ApplicationVersionUpdatedDynamically Then
					// The metadata object might be available after restart.
					If ExceptNonexistentAndUnavailableItems Then
						IDsMetadataObjects.Insert(Properties.Ref, Undefined);
						Continue;
					Else
						// Standard exception caused by dynamic update.
						StandardSubsystemsServer.RequireRestartDueToApplicationVersionDynamicUpdate();
					EndIf;
					
				ElsIf ExceptNonexistentAndUnavailableItems Then
					// The metadata object does not exist.
					IDsMetadataObjects.Insert(Properties.Ref, Null);
					Continue;
					
				ElsIf CheckResult.MetadataObjectKey = Undefined Then
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Идентификатору ""%1""
						           |найденному в справочнике ""%2"",
						           |соответствует несуществующий объект метаданных
						           |""%3"".'; 
						           |en = 'The ID ""%1""
						           |found in catalog ""%2""
						           |matches a nonexisting metadata object
						           |""%3"".'; 
						           |pl = 'Identyfikatorowi ""%1""
						           |znalezionemu w katalogu ""%2"",
						           |odpowiada nieistniejący obiekt metadanych
						           |""%3"".';
						           |es_ES = 'Al identificador ""%1""
						           |encontrado en el catálogo ""%2""
						           |corresponde un objeto no existente de los metadatos
						           |""%3"".';
						           |es_CO = 'Al identificador ""%1""
						           |encontrado en el catálogo ""%2""
						           |corresponde un objeto no existente de los metadatos
						           |""%3"".';
						           |tr = '""%1"" kataloğunda bulunan "
"%2 tanımlayıcısı, mevcut olmayan metaveri nesnesi 
						           |"
" ile uyumludur.%3';
						           |it = 'L''ID""%1""
						           |trovata nel catalogo ""%2""
						           |corrisponde a un oggetto di metadati inesistente
						           |""%3"".';
						           |de = 'Die Kennung ""%1"",
						           |gefunden im Verzeichnis ""%2"",
						           |entspricht einem nicht existierenden Metadatenobjekt
						           |""%3"".'"),
						String(Properties.Ref),
						CatalogDescription(Properties.ExtensionObject),
						Properties.FullName);
				Else
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Идентификатору ""%1""
						           |найденному в справочнике ""%2"",
						           |соответствует удаленный объект метаданных.'; 
						           |en = 'The ID ""%1""
						           |found in catalog ""%2""
						           |matches a deleted metadata object.'; 
						           |pl = 'Identyfikatorowi ""%1""
						           |znalezionemu w katalogu ""%2"",
						           |odpowiada usunięty obiekt metadanych.';
						           |es_ES = 'Al identificador ""%1""
						           |encontrado en el catálogo ""%2""
						           |corresponde un objeto de metadatos eliminado.';
						           |es_CO = 'Al identificador ""%1""
						           |encontrado en el catálogo ""%2""
						           |corresponde un objeto de metadatos eliminado.';
						           |tr = '""%1"" kataloğunda bulunan "
"%2 tanımlayıcısı, uzak metaveri nesnesi 
						           | ile uyumludur.';
						           |it = 'L''ID ""%1""
						           |trovata nel catalogo ""%2""
						           |corrisponde a un oggetto di metadati eliminato.';
						           |de = 'Die Kennung ""%1"",
						           |gefunden im Verzeichnis ""%2"",
						           |entspricht dem nicht entfernten Metadatenobjekt.'"),
						String(Properties.Ref),
						CatalogDescription(Properties.ExtensionObject));
				EndIf;
			ElsIf ApplicationVersionUpdatedDynamically Then
				// The metadata object might have been renamed.
				ErrorDescription = "";
			Else
				ErrorDescription =  StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Идентификатору ""%1""
					           |найденному в справочнике ""%2"",
					           |соответствует объект метаданных ""%3"",
					           |полное имя которого отличается от заданного в идентификаторе.'; 
					           |en = 'The ID ""%1""
					           |found in catalog ""%2""
					           |matches the metadata object ""%3""
					           |whose full name is different from the name specified in the ID.'; 
					           |pl = 'Identyfikatorowi ""%1""
					           |znalezionemu w katalogu ""%2"",
					           |odpowiada obiekt metadanych ""%3"",
					           |pełna nazwa którego różni się od określonej w identyfikatorze.';
					           |es_ES = 'Al identificador ""%1""
					           |encontrado en el catálogo ""%2""
					           |corresponde un objeto de metadatos ""%3""
					           |cuyo nombre completo se diferencia del establecido en el identificador.';
					           |es_CO = 'Al identificador ""%1""
					           |encontrado en el catálogo ""%2""
					           |corresponde un objeto de metadatos ""%3""
					           |cuyo nombre completo se diferencia del establecido en el identificador.';
					           |tr = '""%2"" kataloğunda
					           |bulunan ""%1"" ID''si, tam adı ID''de
					           |belirtilen addan farklı olan ""%3""
					           |metaveri nesnesiyle eşleşiyor.';
					           |it = 'All''identificatore ""%1""
					           | trovato nell''elenco ""%2""
					           | corrisponde un oggetto dei metadati ""%3""
					           | il cui nome completo differisce da quello impostato nell''identificatore.';
					           |de = 'Die Kennung ""%1"",
					           |gefunden im Verzeichnis ""%2"",
					           |mit dem Metadatenobjekt ""%3"",
					           |dessen vollständiger Name sich von dem im Kennung angegebenen unterscheidet.'"),
					String(Properties.Ref),
					CatalogDescription(Properties.ExtensionObject),
					CheckResult.MetadataObject.FullName());
			EndIf;
			
			If ValueIsFilled(ErrorDescription) Then
				Raise ErrorTitle + Chars.LF + Chars.LF + ErrorDescription
					+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper();
			EndIf;
		EndIf;
		
		If Not Properties.ExtensionObject AND Properties.DeletionMark AND Not ApplicationVersionUpdatedDynamically Then
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Идентификатор ""%1""
				           |найден в справочнике ""%2"",
				           |но значение реквизита ""Пометка удаления"" установлено True.'; 
				           |en = 'The ID ""%1""
				           |is found in catalog ""%2""
				           |, but its ""Deletion mark"" attribute is set to True.'; 
				           |pl = 'Identyfikatorowi ""%1""
				           |został znaleziony w katalogu ""%2"",
				           |jednak wartość atrybutu ""Zaznaczenie do usunięcia"" ustawiono True.';
				           |es_ES = 'El identificador ""%1""
				           |no se ha encontrado en el catálogo ""%2""
				           |pero el valor del requisito ""Marca de borrar"" se ha especificado True.';
				           |es_CO = 'El identificador ""%1""
				           |no se ha encontrado en el catálogo ""%2""
				           |pero el valor del requisito ""Marca de borrar"" se ha especificado True.';
				           |tr = '""%1""
				           | tanımlayıcısı ""%2"" katalogunda bulundu, 
				           | ancak ""Silme işareti"" özniteliği değeri Doğru olarak belirlendi.';
				           |it = 'L''identificatore ""%1""
				           |è stato trovato nell''elenco ""%2""
				           | ma il valore del requisito ""Contrassegno per la cancellazione"" è impostato a True.';
				           |de = 'Die Kennung ""%1""
				           |befindet sich im Verzeichnis ""%2"",
				           |aber der Wert des Attributs ""Löschmarkierung"" wird auf True gesetzt.'"),
				String(Properties.Ref),
				CatalogDescription(Properties.ExtensionObject));
			
			Raise ErrorTitle + Chars.LF + Chars.LF + ErrorDescription
				+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper();
		EndIf;
		
		MetadataObjectDetails = New Structure("Object, Key", CheckResult.MetadataObject);
		If CheckResult.MetadataObjectKey <> Undefined Then
			MetadataObjectDetails.Key = CheckResult.MetadataObjectKey;
		Else
			MetadataObjectDetails.Key = Properties.FullName;
		EndIf;
		IDsMetadataObjects.Insert(Properties.Ref, MetadataObjectDetails);
	EndDo;
	
	Return IDsMetadataObjects;
	
EndFunction

// This method is required by MetadataObjectsByIDs and MetadataObjectIDs functions.
Function IDCache()
	
	CachedDataKey = String(SessionParameters.CachedDataKey);
	
	Return StandardSubsystemsCached.MetadataObjectIDCache(CachedDataKey);
	
EndFunction

// Intended to be called from  StandardSubsystemsCached.MetadataObjectIDCache.
Function MetadataObjectIDCache(CachedDataKey) Export
	
	Storage = New Structure;
	Storage.Insert("IDsByFullNames", New Map);
	Storage.Insert("DetailsOfMetadataObjectsByIDs", New Map);
	
	Return New FixedStructure(Storage);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for replacing IDs in databases.

Procedure ReplaceSubordinateNodeDuplicatesFoundOnImport(CheckOnly, HasChanges)
	
	If Common.DataSeparationEnabled() Then
		// Not supported in SaaS mode.
		Return;
	EndIf;
	
	If NOT Common.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	// Replacing the duplicates in a subordinate DIB node.
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref,
	|	IDs.NewRef
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	IDs.NewRef <> VALUE(Catalog.MetadataObjectIDs.EmptyRef)";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	If CheckOnly Then
		HasChanges = True;
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	RefsToReplace = New Array;
	PreviousAndNewRefs = New Map;
	While Selection.Next() Do
		RefsToReplace.Add(Selection.Ref);
		PreviousAndNewRefs.Insert(Selection.Ref, Selection.NewRef);
	EndDo;
	
	CurrentAttempt = 1;
	While True Do
		DataFound = FindByRef(RefsToReplace);
		DataFound.Columns[0].Name = "Ref";
		DataFound.Columns[1].Name = "Data";
		DataFound.Columns[2].Name = "Metadata";
		DataFound.Columns.Add("Enabled");
		DataFound.FillValues(True, "Enabled");
		
		If DataFound.Count() = 0 Then
			Lock = New DataLock;
			LockItem = Lock.Add("Catalog.MetadataObjectIDs");
			For Each RefToReplace In RefsToReplace Do
				LockItem.SetValue("Ref", RefToReplace);
			EndDo;
			BeginTransaction();
			Try
				Lock.Lock();
				// Clearing new references from the duplicates IDs.
				For Each RefToReplace In RefsToReplace Do
					DuplicateObject = RefToReplace.GetObject();
					DuplicateObject.NewRef = Undefined;
					DuplicateObject.DataExchange.Load = True;
					DuplicateObject.Write();
				EndDo;
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
		EndIf;
		
		If CurrentAttempt > 10 Then
			Raise
				NStr("ru = 'Не удалось выполнить замену дублей идентификаторов объектов метаданных.
				           |После 10 попыток все еще имеются данные, которые требуют замены.
				           |Выполните действие в монопольном режиме.'; 
				           |en = 'Cannot replace duplicates of metadata object IDs.
				           |After 10 attempts, there is still data to be replaced.
				           |Please perform this operation in exclusive mode.'; 
				           |pl = 'Zamiana duplikatów identyfikatorów metadanych nie powiodła się.
				           |Po 10 próbach nadal istnieją dane, które wymagają zamiany.
				           |Wykonaj działanie w trybie wyłącznym.';
				           |es_ES = 'No se ha podido reemplazar los duplicados de los identificadores de los objetos de metadatos.
				           |Después de 10 pruebas todavía hay datos que hay que reemplazar.
				           |Realice la acción en el modo monopolio.';
				           |es_CO = 'No se ha podido reemplazar los duplicados de los identificadores de los objetos de metadatos.
				           |Después de 10 pruebas todavía hay datos que hay que reemplazar.
				           |Realice la acción en el modo monopolio.';
				           |tr = 'Meta veri nesne kimlikleri çiftleri değiştirilemedi. 
				           |10 denemeden sonra, değiştirilmesi gereken veriler hala var. 
				           |Özel modda bir eylem gerçekleştirin.';
				           |it = 'Sostituzione degli identificatori duplicati degli oggetti dei metadati non riuscita.
				           |Dopo 10 tentativi, sono ancora presenti dati che devono essere sostituiti.
				           |Eseguite l''operazione in modalità esclusiva.';
				           |de = 'Es war nicht möglich, doppelte Kennungen von Metadaten-Objekten zu ersetzen.
				           |Nach 10 Versuchen gibt es noch Daten, die ersetzt werden müssen.
				           |Führen Sie die Operation im Monopolmodus durch.'");
		EndIf;
		
		WithoutErrors = ExecuteItemReplacement(PreviousAndNewRefs, DataFound, True);
		If Not WithoutErrors Then
			Raise
				NStr("ru = 'Не удалось выполнить замену дублей идентификаторов объектов метаданных.
				           |Подробнее см. ошибки при замене идентификатора в журнале регистрации.'; 
				           |en = 'Cannot replace duplicate metadata object IDs.
				           |For more information, see the ID replacement errors in the event log.'; 
				           |pl = 'Zamiana duplikatów identyfikatorów metadanych nie powiodła się.
				           |Szczegóły zob. błędy przy zamianie identyfikatora w dzienniku rejestracji.';
				           |es_ES = 'No se ha podido reemplazar los duplicados de los identificadores de los objetos de metadatos.
				           |Véase más los errores al reemplazar el identificador en el registro de eventos.';
				           |es_CO = 'No se ha podido reemplazar los duplicados de los identificadores de los objetos de metadatos.
				           |Véase más los errores al reemplazar el identificador en el registro de eventos.';
				           |tr = 'Meta veri nesne kimlikleri çiftleri değiştirilemedi. 
				           |Daha fazla bilgi için olay günlüğündeki ID değişiklik hatalarına bakın.';
				           |it = 'Sostituzione degli identificatori duplicati degli oggetti dei metadati non riuscita.
				           |Per maggiori informazioni controllare gli errori durante la sostituzione dell''identificatore nel registro di registrazione.';
				           |de = 'Es war nicht möglich, doppelte Kennungen von Metadaten-Objekten zu ersetzen.
				           |Weitere Informationen finden Sie unter den Fehlern beim Ändern der Kennung im Ereignisprotokoll.'");
		EndIf;
		CurrentAttempt = CurrentAttempt + 1;
	EndDo;
	
EndProcedure

// The function from the ValueSearchingAndReplacing universal data processor.
// Changes:
// - Operations with the progress bar form are no longer supported.
// - The UserInterruptProcessing procedure is deleted.
// - The InformationRegisters[TableRow.Metadata.Name] is replaced with
//   Common.ObjectManagerByFullName(TableRow.Metadata.FullName()).
//
Function ExecuteItemReplacement(Val Replaceable, Val RefTable, Val DisableWriteControl = False, Val ExtensionsObjects = False)
	
	Parameters = New Structure;
	
	For Each AccountingRegister In Metadata.AccountingRegisters Do
		Parameters.Insert(AccountingRegister.Name + "ExtDimensions",        AccountingRegister.ChartOfAccounts.MaxExtDimensionCount);
		Parameters.Insert(AccountingRegister.Name + "Correspondence", AccountingRegister.Correspondence);
	EndDo;
	
	Parameters.Insert("Object", Undefined);
	
	RefToProcess = Undefined;
	HadExceptions = False;
	
	Try
		For Each TableRow In RefTable Do
			If Not TableRow.Enabled Then
				Continue;
			EndIf;
			CorrectItem = Replaceable[TableRow.Ref];
			
			Ref = TableRow.Ref;
			
			If RefToProcess <> TableRow.Data Then
				If RefToProcess <> Undefined AND Parameters.Object <> Undefined Then
					
					Try
						Parameters.Object.DataExchange.Load = True;
						If DisableWriteControl Then
							Parameters.Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
							InfobaseUpdate.WriteData(Parameters.Object, False);
						Else
							Parameters.Object.Write();
						EndIf;
					Except
						HadExceptions = True;
						ErrorInformation = ErrorInfo();
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("ru = 'При записи объекта ""%1"" возникла ошибка:
							           |%2'; 
							           |en = 'Cannot save object ""%1"":
							           |%2'; 
							           |pl = 'Podczas zapisu obiektu ""%1"" zaistniał błąd:
							           |%2';
							           |es_ES = 'Al guardar el objeto ""%1"" ha ocurrido un error:
							           |%2';
							           |es_CO = 'Al guardar el objeto ""%1"" ha ocurrido un error:
							           |%2';
							           |tr = '""%1"" düzeltme kaydedildiğinde bir hata oluştu:
							           |%2';
							           |it = 'Durante la scrittura dell''oggetto ""%1"" si è verificato un errore:
							           |%2';
							           |de = 'Beim Schreiben des Objekts ""%1"" ist ein Fehler aufgetreten:
							           |%2'"),
							GetURL(Parameters.Object.Ref),
							DetailErrorDescription(ErrorInformation));
						If TransactionActive() Then
							Raise ErrorText;
						EndIf;
						ReportError(ErrorText, ExtensionsObjects);
					EndTry;
					Parameters.Object = Undefined;
				EndIf;
				RefToProcess = TableRow.Data;
			EndIf;
			
			If Metadata.Documents.Contains(TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				For Each Attribute In TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) AND Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
					
				For Each TabularSection In TableRow.Metadata.TabularSections Do
					For Each Attribute In TabularSection.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabularSectionRow = Parameters.Object[TabularSection.Name].Find(Ref, Attribute.Name);
							While TabularSectionRow <> Undefined Do
								TabularSectionRow[Attribute.Name] = CorrectItem;
								TabularSectionRow = Parameters.Object[TabularSection.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
				For Each RegisterRecord In TableRow.Metadata.RegisterRecords Do
					
					IsAccountingRegisterRecord = Metadata.AccountingRegisters.Contains(RegisterRecord);
					HasCorrespondence = IsAccountingRegisterRecord AND Parameters[RegisterRecord.Name + "Correspondence"];
					
					RecordSet = Parameters.Object.RegisterRecords[RegisterRecord.Name];
					RecordSet.Read();
					MustWrite = False;
					SetTable = RecordSet.Unload();
					
					If SetTable.Count() = 0 Then
						Continue;
					EndIf;
					
					ColumnNames = New Array;
					
					// Getting names of dimensions that might contain references.
					For Each Dimension In RegisterRecord.Dimensions Do
						
						If Dimension.Type.ContainsType(TypeOf(Ref)) Then
							
							If IsAccountingRegisterRecord Then
								
								If Dimension.AccountingFlag <> Undefined Then
									
									ColumnNames.Add(Dimension.Name + "Dr");
									ColumnNames.Add(Dimension.Name + "Cr");
								Else
									ColumnNames.Add(Dimension.Name);
								EndIf;
							Else
								ColumnNames.Add(Dimension.Name);
							EndIf;
						EndIf;
					EndDo;
					
					// Getting names of resources that might contain references.
					If Metadata.InformationRegisters.Contains(RegisterRecord) Then
						For Each Resource In RegisterRecord.Resources Do
							If Resource.Type.ContainsType(TypeOf(Ref)) Then
								ColumnNames.Add(Resource.Name);
							EndIf;
						EndDo;
					EndIf;
					
					// Getting names of resources that might contain references.
					For Each Attribute In RegisterRecord.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							ColumnNames.Add(Attribute.Name);
						EndIf;
					EndDo;
					
					// Making replacements in the table.
					For Each ColumnName In ColumnNames Do
						TabSectionRow = SetTable.Find(Ref, ColumnName);
						While TabSectionRow <> Undefined Do
							TabSectionRow[ColumnName] = CorrectItem;
							MustWrite = True;
							TabSectionRow = SetTable.Find(Ref, ColumnName);
						EndDo;
					EndDo;
					
					If Metadata.AccountingRegisters.Contains(RegisterRecord) Then
						
						For ExtDimensionIndex = 1 To Parameters[RegisterRecord.Name + "ExtDimensions"] Do
							If HasCorrespondence Then
								TabSectionRow = SetTable.Find(Ref, "ExtDimensionsDr"+ExtDimensionIndex);
								While TabSectionRow <> Undefined Do
									TabSectionRow["ExtDimensionsDr"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabSectionRow = SetTable.Find(Ref, "ExtDimensionsDr"+ExtDimensionIndex);
								EndDo;
								TabSectionRow = SetTable.Find(Ref, "ExtDimensionsCr"+ExtDimensionIndex);
								While TabSectionRow <> Undefined Do
									TabSectionRow["ExtDimensionsCr"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabSectionRow = SetTable.Find(Ref, "ExtDimensionsCr"+ExtDimensionIndex);
								EndDo;
							Else
								TabSectionRow = SetTable.Find(Ref, "ExtDimensions"+ExtDimensionIndex);
								While TabSectionRow <> Undefined Do
									TabSectionRow["ExtDimensions"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabSectionRow = SetTable.Find(Ref, "ExtDimensions"+ExtDimensionIndex);
								EndDo;
							EndIf;
						EndDo;
						
						If Ref.Metadata() = RegisterRecord.ChartOfAccounts Then
							For Each TabSectionRow In SetTable Do
								If HasCorrespondence Then
									If TabSectionRow.AccountDr = Ref Then
										TabSectionRow.AccountDr = CorrectItem;
										MustWrite = True;
									EndIf;
									If TabSectionRow.AccountCr = Ref Then
										TabSectionRow.AccountCr = CorrectItem;
										MustWrite = True;
									EndIf;
								Else
									If TabSectionRow.Account = Ref Then
										TabSectionRow.Account = CorrectItem;
										MustWrite = True;
									EndIf;
								EndIf;
							EndDo;
						EndIf;
					EndIf;
					
					If Metadata.CalculationRegisters.Contains(RegisterRecord) Then
						TabSectionRow = SetTable.Find(Ref, "CalculationType");
						While TabSectionRow <> Undefined Do
							TabSectionRow["CalculationType"] = CorrectItem;
							MustWrite = True;
							TabSectionRow = SetTable.Find(Ref, "CalculationType");
						EndDo;
					EndIf;
					
					If MustWrite Then
						RecordSet.Load(SetTable);
						Try
							If DisableWriteControl Then
								RecordSet.AdditionalProperties.Insert("SkipObjectVersionRecord");
								InfobaseUpdate.WriteData(RecordSet, False);
							Else
								RecordSet.Write();
							EndIf;
						Except
							HadExceptions = True;
							ErrorInformation = ErrorInfo();
							ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("ru = 'При записи движений объекта ""%1"" в ""%2"" возникла ошибка:
								           |%3'; 
								           |en = 'Cannot save register records of object ""%1"" to record set ""%2"":
								           |%3'; 
								           |pl = 'Podczas zapisu ruchów obiektu ""%1"" w ""%2"" zaistniał błąd:
								           |%3';
								           |es_ES = 'Al guardar los movimientos del objeto ""%1"" en ""%2"" ha ocurrido un error: 
								           |%3';
								           |es_CO = 'Al guardar los movimientos del objeto ""%1"" en ""%2"" ha ocurrido un error: 
								           |%3';
								           |tr = '""%1"" nesnenin hareketlerinin kaydı esnasında ""%2"" ''de bir hata oluştu: 
								           |%3';
								           |it = 'Durante la scrittura dei movimenti dell''oggetto ""%1"" in ""%2"" si è verificato un errore:
								           |%3';
								           |de = 'Bei der Aufzeichnung der Bewegungen des Objekts ""%1"" nach ""%2"" ist ein Fehler aufgetreten:
								           |%3'"),
								GetURL(Parameters.Object.Ref),
								RecordSet.Metadata().FullName(),
								DetailErrorDescription(ErrorInformation));
							If TransactionActive() Then
								Raise ErrorText;
							EndIf;
							ReportError(ErrorText, ExtensionsObjects);
						EndTry;
					EndIf;
				EndDo;
				
				For Each Sequence In Metadata.Sequences Do
					If Sequence.Documents.Contains(TableRow.Metadata) Then
						MustWrite = False;
						SingleRecordSet = Sequences[Sequence.Name].CreateRecordSet();
						SingleRecordSet.Filter.Recorder.Set(TableRow.Data);
						SingleRecordSet.Read();
						
						If SingleRecordSet.Count() > 0 Then
							For Each Dimension In Sequence.Dimensions Do
								If Dimension.Type.ContainsType(TypeOf(Ref)) AND SingleRecordSet[0][Dimension.Name]=Ref Then
									SingleRecordSet[0][Dimension.Name] = CorrectItem;
									MustWrite = True;
								EndIf;
							EndDo;
							If MustWrite Then
								Try
									If DisableWriteControl Then
										SingleRecordSet.AdditionalProperties.Insert("SkipObjectVersionRecord");
										InfobaseUpdate.WriteData(SingleRecordSet, False);
									Else
										SingleRecordSet.Write();
									EndIf;
								Except
									HadExceptions = True;
									ErrorInformation = ErrorInfo();
									ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
											NStr("ru = 'При записи по регистратору ""%1"" в ""%2"" возникла ошибка:
											           |%3'; 
											           |en = 'Cannot save register records for recorder ""%1"" to record set ""%2"":
											           |%3'; 
											           |pl = 'Podczas zapisu według rejestratora ""%1"" ""%2"" zaistniał błąd:
											           |%3';
											           |es_ES = 'Al guardar por el registrador ""%1"" en ""%2"" ha ocurrido un error: 
											           |%3';
											           |es_CO = 'Al guardar por el registrador ""%1"" en ""%2"" ha ocurrido un error: 
											           |%3';
											           |tr = '""%1"" kaydedicinin kaydı esnasında ""%2"" ''de bir hata oluştu: 
											           |%3';
											           |it = 'Impossibile salvare registrazione per il Documento di Rif ""%1"" all''insieme di registrazioni ""%2"":
											           |%3""';
											           |de = 'Beim Aufzeichnen mit dem Registrator ""%1"" nach ""%2"" ist ein Fehler aufgetreten:
											           |%3'"),
											GetURL(TableRow.Data),
											SingleRecordSet.Metadata().FullName(),
											DetailErrorDescription(ErrorInformation));
									If TransactionActive() Then
										Raise ErrorText;
									EndIf;
									ReportError(ErrorText, ExtensionsObjects);
								EndTry;
							EndIf;
						EndIf;
					EndIf;
				EndDo;
				
			ElsIf Metadata.Catalogs.Contains(TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				If TableRow.Metadata.Owners.Contains(Ref.Metadata()) AND Parameters.Object.Owner = Ref Then
					Parameters.Object.Owner = CorrectItem;
				EndIf;
				
				If TableRow.Metadata.Hierarchical AND Parameters.Object.Parent = Ref Then
					Parameters.Object.Parent = CorrectItem;
				EndIf;
				
				For Each Attribute In TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) AND Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
				
				For Each TS In TableRow.Metadata.TabularSections Do
					For Each Attribute In TS.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							While TabSectionRow <> Undefined Do
								TabSectionRow[Attribute.Name] = CorrectItem;
								TabSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
			ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(TableRow.Metadata)
			      OR Metadata.ChartsOfAccounts.Contains            (TableRow.Metadata)
			      OR Metadata.ChartsOfCalculationTypes.Contains      (TableRow.Metadata)
			      OR Metadata.Tasks.Contains                 (TableRow.Metadata)
			      OR Metadata.BusinessProcesses.Contains         (TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				For Each Attribute In TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) AND Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
				
				For Each TS In TableRow.Metadata.TabularSections Do
					For Each Attribute In TS.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							While TabSectionRow <> Undefined Do
								TabSectionRow[Attribute.Name] = CorrectItem;
								TabSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
			ElsIf Metadata.Constants.Contains(TableRow.Metadata) Then
				
				Common.ObjectManagerByFullName(
					TableRow.Metadata.FullName()).Set(CorrectItem);
				
			ElsIf Metadata.InformationRegisters.Contains(TableRow.Metadata) Then
				
				DimensionStructure = New Structure;
				RegisterManager = Common.ObjectManagerByFullName(TableRow.Metadata.FullName());
				RecordSet = RegisterManager.CreateRecordSet();
				For Each Dimension In TableRow.Metadata.Dimensions Do
					RecordSet.Filter[Dimension.Name].Set(TableRow.Data[Dimension.Name]);
					DimensionStructure.Insert(Dimension.Name, TableRow.Data[Dimension.Name]);
				EndDo;
				If TableRow.Metadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
					RecordSet.Filter["Period"].Set(TableRow.Data.Period);
				EndIf;
				RecordSet.Read();
				
				If RecordSet.Count() = 0 Then
					Continue;
				EndIf;
				
				SetTable = RecordSet.Unload();
				RecordSet.Clear();
				
				ErrorText = "";
				BeginTransaction();
				Try
					Try
						If DisableWriteControl Then
							RecordSet.AdditionalProperties.Insert("SkipObjectVersionRecord");
							InfobaseUpdate.WriteData(RecordSet, False);
						Else
							RecordSet.Write();
						EndIf;
					Except
						ErrorInformation = ErrorInfo();
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("ru = 'При удалении записи ""%1"" возникла ошибка:
							           |%2'; 
							           |en = 'Cannot delete record ""%1"":
							           |%2'; 
							           |pl = 'Podczas usuwania zapisu ""%1"" zaistniał błąd:
							           |%2';
							           |es_ES = 'Al eliminar el registro ""%1"" ha ocurrido un error:
							           |%2';
							           |es_CO = 'Al eliminar el registro ""%1"" ha ocurrido un error:
							           |%2';
							           |tr = '""%1"" kayıt silindiğinde bir hata oluştu:
							           |%2';
							           |it = 'Durante l''eliminazione del record ""%1"" si è verificato un errore:
							           |%2';
							           |de = 'Beim Löschen des Eintrags ""%1"" ist ein Fehler aufgetreten:
							           |%2'"),
							GetURL(RegisterManager.CreateRecordKey(DimensionStructure)),
							DetailErrorDescription(ErrorInformation));
						Raise;
					EndTry;
					
					For Each Column In SetTable.Columns Do
						If SetTable[0][Column.Name] = Ref Then
							SetTable[0][Column.Name] = CorrectItem;
							If DimensionStructure.Property(Column.Name) Then
								RecordSet.Filter[Column.Name].Set(CorrectItem);
								DimensionStructure[Column.Name] = CorrectItem;
							EndIf;
						EndIf;
					EndDo;
					
					RecordSet.Load(SetTable);
					
					Try
						If DisableWriteControl Then
							RecordSet.AdditionalProperties.Insert("SkipObjectVersionRecord");
							InfobaseUpdate.WriteData(RecordSet, False);
						Else
							RecordSet.Write();
						EndIf;
					Except
						ErrorInformation = ErrorInfo();
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("ru = 'При добавлении записи ""%1"" возникла ошибка:
							           |%2'; 
							           |en = 'Cannot add record ""%1"":
							           |%2'; 
							           |pl = 'Podczas dodawania zapisu ""%1"" zaistniał błąd:
							           |%2';
							           |es_ES = 'Al añadir el registro ""%1"" ha ocurrido un error:
							           |%2';
							           |es_CO = 'Al añadir el registro ""%1"" ha ocurrido un error:
							           |%2';
							           |tr = '""%1"" kayıt eklendiğinde bir hata oluştu: 
							           |%2';
							           |it = 'Durante l''aggiunta del record ""%1"" si è verificato un errore:
							           |%2';
							           |de = 'Beim Hinzufügen eines ""%1"" Eintrags ist ein Fehler aufgetreten:
							           |%2'"),
							GetURL(RegisterManager.CreateRecordKey(DimensionStructure)),
							DetailErrorDescription(ErrorInformation));
						Raise;
					EndTry;
					
					CommitTransaction();
				Except
					RollbackTransaction();
					HadExceptions = True;
					If Not ValueIsFilled(ErrorText) Then
						Raise;
					EndIf;
					If TransactionActive() Then
						Raise ErrorText;
					EndIf;
					ReportError(ErrorText, ExtensionsObjects);
				EndTry;
			Else
				ReportError(NStr("ru = 'Значения не заменяются в данных типа'; en = 'Values are not replaced in data of the following type'; pl = 'Wartości nie są zmieniane w danych typu';es_ES = 'Valores no se han cambiado en los datos del tipo';es_CO = 'Valores no se han cambiado en los datos del tipo';tr = 'Değerler, veri türünde değiştirilmez';it = 'I valori non sono sostituiti nei dati del seguente tipo';de = 'Werte werden in den Typ-Daten nicht geändert'")
					+ ": " + String(TableRow.Metadata), ExtensionsObjects);
			EndIf;
		EndDo;
	
		If Parameters.Object <> Undefined Then
			Try
				If DisableWriteControl Then
					Parameters.Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
					InfobaseUpdate.WriteData(Parameters.Object, False);
				Else
					Parameters.Object.Write();
				EndIf;
			Except
				HadExceptions = True;
				ErrorInformation = ErrorInfo();
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'При записи объекта ""%1"" возникла ошибка:
					           |%2'; 
					           |en = 'Cannot save object ""%1"":
					           |%2'; 
					           |pl = 'Podczas zapisu obiektu ""%1"" zaistniał błąd:
					           |%2';
					           |es_ES = 'Al guardar el objeto ""%1"" ha ocurrido un error:
					           |%2';
					           |es_CO = 'Al guardar el objeto ""%1"" ha ocurrido un error:
					           |%2';
					           |tr = '""%1"" düzeltme kaydedildiğinde bir hata oluştu:
					           |%2';
					           |it = 'Durante la scrittura dell''oggetto ""%1"" si è verificato un errore:
					           |%2';
					           |de = 'Beim Schreiben des Objekts ""%1"" ist ein Fehler aufgetreten:
					           |%2'"),
					GetURL(Parameters.Object.Ref),
					DetailErrorDescription(ErrorInformation));
				If TransactionActive() Then
					Raise ErrorText;
				EndIf;
				ReportError(ErrorText, ExtensionsObjects);
			EndTry;
		EndIf;
		
	Except
		HadExceptions = True;
		Raise;
	EndTry;
	
	Return Not HadExceptions;
	
EndFunction

// Procedure from the ValueSearchingAndReplacing universal data processor.
// Changes:
// - The Message(...) method is replaced with the WriteLogEvent(...) method.
//
Procedure ReportError(Val Details, ExtensionsObjects)
	
	WriteLogEvent(
		?(ExtensionsObjects,
			NStr("ru = 'Идентификаторы объектов расширений.Замена идентификатора'; en = 'Extension object IDs.ID replacement'; pl = 'Identyfikatory obiektów rozszerzeń.Zamiana identyfikatora';es_ES = 'Identificadores de los objetos de las extensiones.Cambio del identificador';es_CO = 'Identificadores de los objetos de las extensiones.Cambio del identificador';tr = 'Uzantı nesne tanımlayıcıları. Tanımlayıcı değiştirme';it = 'Identificatori degli oggetti delle estensioni. Sostituzione dell''identificatore';de = 'Identifikatoren des Erweiterungsobjekts. Ersetzen des Identifikators'",
				CommonClientServer.DefaultLanguageCode()),
			NStr("ru = 'Идентификаторы объектов метаданных.Замена идентификатора'; en = 'Metadata object IDs.ID replacement'; pl = 'Identyfikatory obiektów metadanych.Zamiana identyfikatora';es_ES = 'Identificadores de los objetos de los metadatos del identificador.Cambio del identificador';es_CO = 'Identificadores de los objetos de los metadatos del identificador.Cambio del identificador';tr = 'Metaveri nesne tanımlayıcıları. Tanımlayıcı değiştirme';it = 'Identificatori degli oggetti dei metadati. Sostituzione dell''identificatore';de = 'Identifikatoren von Metadatenobjekten. Ersetzen des Identifikators'",
				CommonClientServer.DefaultLanguageCode())),
		EventLogLevel.Error,
		,
		,
		Details,
		EventLogEntryTransactionMode.Independent);
	
EndProcedure

#EndRegion

#EndIf