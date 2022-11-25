
#Region ServiceProceduresAndFunctions

// Update bank of the classifier and also set
// the current state (ManualChanging attribute). We are searching for the link by BIC.
// You shall update only that items which attribute
// does not match the same attribute in the classifier
//
// Parameters:
//
//  - BankList - Array - items with the CatalogRef.BankClassifier type - the list of
//                       banks to be updated if the list is empty, then it is necessary to check all items and update
//                       the changed ones
//
//  - DataArea - Number(1, 0) - data area to be updated for
//                              the local mode = 0 if the data area is not transferred, the update is not performed.
//
Function RefreshBanksFromClassifier(Val BankList = Undefined, Val DataArea) Export
	
	AreaProcessed  = True;
	If DataArea = Undefined Then
		Return AreaProcessed;
	EndIf;
	
	Query = New Query;
	QueryText =
	"SELECT
	|	BankClassifier.Code AS Code,
	|	BankClassifier.Description,
	|	BankClassifier.City,
	|	BankClassifier.Address,
	|	BankClassifier.Phones,
	|	BankClassifier.IsFolder,
	|	BankClassifier.Parent.Code,
	|	BankClassifier.Parent.Description,
	|	BankClassifier.OutOfBusiness
	|INTO TU_ChangedBanks
	|FROM
	|	Catalog.BankClassifier AS BankClassifier
	|WHERE
	|	BankClassifier.Ref IN(&BankList)
	|
	|INDEX BY
	|	Code
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	SubqueryBanks.Bank AS Bank,
	|	SubqueryBanks.Code AS Code,
	|	SubqueryBanks.Description AS Description,
	|	SubqueryBanks.City AS City,
	|	SubqueryBanks.Address AS Address,
	|	SubqueryBanks.Phones AS Phones,
	|	SubqueryBanks.IsFolder AS IsFolder,
	|	SubqueryBanks.ParentCode AS ParentCode,
	|	SubqueryBanks.ParentDescription AS ParentDescription,
	|	SubqueryBanks.OutOfBusiness AS OutOfBusiness
	|INTO TU_ChangedItems
	|FROM
	|	(SELECT
	|		Banks.Ref AS Bank,
	|		TU_ChangedBanks.Code AS Code,
	|		TU_ChangedBanks.Description AS Description,
	|		TU_ChangedBanks.City AS City,
	|		TU_ChangedBanks.Address AS Address,
	|		TU_ChangedBanks.Phones AS Phones,
	|		TU_ChangedBanks.IsFolder AS IsFolder,
	|		TU_ChangedBanks.ParentCode AS ParentCode,
	|		TU_ChangedBanks.ParentDescription AS ParentDescription,
	|		TU_ChangedBanks.OutOfBusiness AS OutOfBusiness
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.Description <> TU_ChangedBanks.Description
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.Phones,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.OutOfBusiness
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.City <> TU_ChangedBanks.City
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.Phones,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.OutOfBusiness
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.Address <> TU_ChangedBanks.Address
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.Phones,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.OutOfBusiness
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.PhoneNumbers <> TU_ChangedBanks.Phones
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.Phones,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.OutOfBusiness
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND Banks.Parent.Code <> TU_ChangedBanks.ParentCode
	|				AND (Banks.ManualChanging = 0)
	|	WHERE
	|		Not Banks.IsFolder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Banks.Ref,
	|		TU_ChangedBanks.Code,
	|		TU_ChangedBanks.Description,
	|		TU_ChangedBanks.City,
	|		TU_ChangedBanks.Address,
	|		TU_ChangedBanks.Phones,
	|		TU_ChangedBanks.IsFolder,
	|		TU_ChangedBanks.ParentCode,
	|		TU_ChangedBanks.ParentDescription,
	|		TU_ChangedBanks.OutOfBusiness
	|	FROM
	|		Catalog.Banks AS Banks
	|			INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|			ON Banks.Code = TU_ChangedBanks.Code
	|				AND Banks.IsFolder = TU_ChangedBanks.IsFolder
	|				AND (Banks.ManualChanging = 2)
	|	WHERE
	|		Not Banks.IsFolder) AS SubqueryBanks
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TU_ChangedItems.Bank AS Bank,
	|	TU_ChangedItems.Code AS Code,
	|	TU_ChangedItems.Description AS Description,
	|	TU_ChangedItems.City AS City,
	|	TU_ChangedItems.Address AS Address,
	|	TU_ChangedItems.Phones AS Phones,
	|	TU_ChangedItems.IsFolder AS IsFolder,
	|	0 AS ManualChanging,
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Parent,
	|	TU_ChangedItems.ParentCode AS ParentCode,
	|	TU_ChangedItems.ParentDescription AS ParentDescription,
	|	TU_ChangedItems.OutOfBusiness AS OutOfBusiness
	|FROM
	|	TU_ChangedItems AS TU_ChangedItems
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_ChangedItems.ParentCode = Banks.Code
	|
	|UNION ALL
	|
	|SELECT
	|	Banks.Ref,
	|	TU_ChangedBanks.Code,
	|	TU_ChangedBanks.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.IsFolder,
	|	0,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.OutOfBusiness
	|FROM
	|	Catalog.Banks AS Banks
	|		INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|		ON Banks.Code = TU_ChangedBanks.Code
	|			AND Banks.Description <> TU_ChangedBanks.Description
	|			AND (Banks.ManualChanging = 0)
	|WHERE
	|	TU_ChangedBanks.IsFolder
	|
	|UNION ALL
	|
	|SELECT
	|	Banks.Ref,
	|	TU_ChangedBanks.Code,
	|	TU_ChangedBanks.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.IsFolder,
	|	0,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TU_ChangedBanks.OutOfBusiness
	|FROM
	|	Catalog.Banks AS Banks
	|		INNER JOIN TU_ChangedBanks AS TU_ChangedBanks
	|		ON Banks.Code = TU_ChangedBanks.Code
	|			AND (Banks.ManualChanging = 2)
	|WHERE
	|	TU_ChangedBanks.IsFolder
	|
	|ORDER BY
	|	IsFolder DESC";
	
	If BankList = Undefined OR BankList.Count() = 0 Then
		QueryText = StrReplace(QueryText, "
			|WHERE
			|	BankClassifier.Ref IN(&BankList)", "");
	Else
		Query.SetParameter("BankList",  BankList);
	EndIf;
	
	Query.Text = QueryText;
	BanksSelection = Query.Execute().Select();
	
	ExcludingPropertiesForItem = "IsFolder";
	ExcludingPropertiesForGroup = "Address, City, PhoneNumbers, Parent, IsFolder";
	
	LangCode = CommonClientServer.DefaultLanguageCode();
	
	While BanksSelection.Next() Do
		
		Bank = BanksSelection.Bank.GetObject();
		FillPropertyValues(Bank, BanksSelection,,
			?(BanksSelection.IsFolder, ExcludingPropertiesForGroup, ExcludingPropertiesForItem));
		
		If Not BanksSelection.IsFolder AND Not ValueIsFilled(BanksSelection.Parent) AND Not IsBlankString(BanksSelection.ParentCode) Then
			Parent = RefOnBank(BanksSelection.ParentCode, True);
			If Not ValueIsFilled(Parent) Then
				Parent = Catalogs.Banks.CreateFolder();
				Parent.Code          = BanksSelection.ParentCode;
				Parent.Description = BanksSelection.ParentDescription;
				
				Try
					Parent.Write();
				Except
					MessagePattern = NStr("en = 'Error when recording the bank-group (state) %1.
										  |%2'; 
										  |ru = 'Ошибка записи группы банков (состояние) %1.
										  |%2';
										  |pl = 'Błąd podczas zapisu grupy bankowej (stan) %1.
										  |%2';
										  |es_ES = 'Error al grabar el grupo-banco (estado) %1.
										  |%2';
										  |es_CO = 'Error al grabar el grupo-banco (estado) %1.
										  |%2';
										  |tr = 'Banka grubu (durum) kaydedilirken bir hata oluştu%1.
										  |%2';
										  |it = 'Errore durante la registrazione del gruppo bancario (stato) %1.
										  |%2';
										  |de = 'Fehler beim Aufzeichnen der Bankgruppe (Status) %1.
										  |%2'",
										LangCode);
					
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern,
						BanksSelection.ParentDescription,
						DetailErrorDescription(ErrorInfo()));
						
					DataAreaNumber = ?(CommonCached.DataSeparationEnabled(),
						" " + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'in area %1'; ru = 'в области %1';pl = 'w obszarze %1';es_ES = 'en el área %1';es_CO = 'en el área %1';tr = '%1 alanda';it = 'nell''area %1';de = 'im Bereich %1'"), DataArea),
						"");
						
					EventName = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Banks refresh %1'; ru = 'Обновление банков %1';pl = 'Odśwież banki %1';es_ES = 'Actualización de los bancos %1';es_CO = 'Actualización de los bancos %1';tr = 'Bankalar yenilemesi %1';it = 'Banche riaggiornamento %1';de = 'Banken erneuern %1'", LangCode),
						DataAreaNumber);
						
					WriteLogEvent(
						EventName,
						EventLogLevel.Error,,,
						MessageText);
					
					AreaProcessed = False;
					Break;
				EndTry
			EndIf;
			
			Bank.Parent = Parent.Ref;
		EndIf;
		
		Try
			Bank.Write();
		Except
			MessagePattern = NStr("en = 'Error when recording the bank with BIC %1 %2'; ru = 'Ошибка записи банка с БИК %1 %2';pl = 'Błąd podczas nagrywania banku za pomocą BIC %1 %2';es_ES = 'Error al guardar el banco con BIC %1 %2';es_CO = 'Error al guardar el banco con BIC %1 %2';tr = 'BIC %1 %2 ile banka kaydedilirken bir hata oluştu';it = 'Errore durante la registrazione della banca con BIC %1 %2';de = 'Fehler bei der Erfassung der Bank mit BIC %1 %2'",
								LangCode);
				
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern,
				BanksSelection.Code,
				DetailErrorDescription(ErrorInfo()));
				
			DataAreaNumber = ?(CommonCached.DataSeparationEnabled(),
				StringFunctionsClientServer.SubstituteParametersToString(" " + NStr("en = 'in area %1'; ru = 'в области %1';pl = 'w obszarze %1';es_ES = 'en el área %1';es_CO = 'en el área %1';tr = '%1 alanda';it = 'nell''area %1';de = 'im Bereich %1'", LangCode), DataArea),
				"");
				
			EventName = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Banks refresh %1'; ru = 'Обновление банков %1';pl = 'Odśwież banki %1';es_ES = 'Actualización de los bancos %1';es_CO = 'Actualización de los bancos %1';tr = 'Bankalar yenilemesi %1';it = 'Banche riaggiornamento %1';de = 'Banken erneuern %1'", LangCode),
					DataAreaNumber);
					
			WriteLogEvent(EventName,
				EventLogLevel.Error,,,
				MessageText);
			
			AreaProcessed = False;
		EndTry;
		
	EndDo;
	
	If Not AreaProcessed Then
		Return AreaProcessed;
	EndIf;
	
	// Find banks with the lost classifier
	// connection and set the appropriate sign
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.Ref AS Bank,
	|	2 AS ManualChanging
	|FROM
	|	Catalog.Banks AS Banks
	|		LEFT JOIN Catalog.BankClassifier AS BankClassifier
	|		ON Banks.Code = BankClassifier.Code
	|WHERE
	|	BankClassifier.Ref IS NULL 
	|	AND Banks.ManualChanging <> 2
	|
	|UNION
	|
	|SELECT
	|	Banks.Ref,
	|	3
	|FROM
	|	Catalog.Banks AS Banks
	|		LEFT JOIN Catalog.BankClassifier AS BankClassifier
	|		ON Banks.Code = BankClassifier.Code
	|WHERE
	|	BankClassifier.OutOfBusiness
	|	AND Banks.ManualChanging < 2";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Bank = Selection.Bank.GetObject();
		Bank.ManualChanging = Selection.ManualChanging;
		
		Try
			Bank.Write();
		Except
			MessagePattern = NStr("en = 'Error when recording the bank with BIC %1 %2'; ru = 'Ошибка записи банка с БИК %1 %2';pl = 'Błąd podczas nagrywania banku za pomocą BIC %1 %2';es_ES = 'Error al guardar el banco con BIC %1 %2';es_CO = 'Error al guardar el banco con BIC %1 %2';tr = 'BIC %1 %2 ile banka kaydedilirken bir hata oluştu';it = 'Errore durante la registrazione della banca con BIC %1 %2';de = 'Fehler bei der Erfassung der Bank mit BIC %1 %2'", LangCode);
								
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern,
				BanksSelection.Code,
				DetailErrorDescription(ErrorInfo()));
				
			DataAreaNumber = ?(CommonCached.DataSeparationEnabled(),
				StringFunctionsClientServer.SubstituteParametersToString(
					" " + NStr("en = 'in %1 field'; ru = 'в поле %1';pl = 'w polu %1';es_ES = 'en el campo %1';es_CO = 'en el campo %1';tr = 'alanda%1';it = 'nel campo %1';de = 'im %1 Feld'", LangCode),
					DataArea),
				"");
			
			EventName = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Banks refresh %1'; ru = 'Обновление банков %1';pl = 'Odśwież banki %1';es_ES = 'Actualización de los bancos %1';es_CO = 'Actualización de los bancos %1';tr = 'Bankalar yenilemesi %1';it = 'Banche riaggiornamento %1';de = 'Banken erneuern %1'",
					LangCode),
				DataAreaNumber);
				
			WriteLogEvent(EventName,
				EventLogLevel.Error,,,
				MessageText);
			
			AreaProcessed = False;
		EndTry;
		
	EndDo;
	
	Return AreaProcessed;
	
EndFunction

// Specifies the text of the
// divided object state, sets the availability of the state control buttons and ReadOnly flag form
//
Procedure ProcessManualEditFlag(Val Form)
	
	Items  = Form.Items;
	
	If Form.ManualChanging = Undefined Then
		If Form.OutOfBusiness Then
			Form.ManualEditText = "";
		Else
			Form.ManualEditText = NStr("en = 'The item is created manually. Automatic update is impossible.'; ru = 'Данный элемент был создан вручную. Автоматическое обновление невозможно.';pl = 'Procedura jest tworzona ręcznie. Automatyczna aktualizacja jest niemożliwa.';es_ES = 'El artículo se ha creado manualmente. La actualización automática es imposible.';es_CO = 'El artículo se ha creado manualmente. La actualización automática es imposible.';tr = 'Öğe manuel olarak oluşturuldu. Otomatik güncelleme yapılamaz.';it = 'L''elemento viene creato manualmente. L''aggiornamento automatico è impossibile.';de = 'Der Artikel wird manuell erstellt. Automatische Aktualisierung ist nicht möglich.'");
		EndIf;
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = True;
		Items.Code.Enabled      = True;
	ElsIf Form.ManualChanging = True Then
		Form.ManualEditText = NStr("en = 'Automatic item update is disabled.'; ru = 'Автоматическое обновление элемента невозможно.';pl = 'Automatyczna aktualizacja produktu jest wyłączona.';es_ES = 'La actualización automática de artículos está desactivada.';es_CO = 'La actualización automática de artículos está desactivada.';tr = 'Otomatik öğe güncellemesi devre dışı.';it = 'L''aggiornamento automatico oggetto è disabilitato.';de = 'Die automatische Artikelaktualisierung ist deaktiviert.'");
		
		Items.UpdateFromClassifier.Enabled = True;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = False;
		Items.Code.Enabled      = False;
	Else
		Form.ManualEditText = NStr("en = 'Item is updated automatically.'; ru = 'Элемент обновлен автоматически.';pl = 'Element jest aktualizowany automatycznie.';es_ES = 'Artículo está actualizado automáticamente.';es_CO = 'Artículo está actualizado automáticamente.';tr = 'Ürün otomatik olarak güncellendi.';it = 'Elemento viene aggiornato automaticamente.';de = 'Artikel wird automatisch aktualisiert.'");
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = True;
		Form.ReadOnly          = True;
	EndIf;
	
EndProcedure

// It reads the object current state
// and makes the form compliant with it
//
Procedure ReadManualEditFlag(Val Form) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.ManualChanging AS ManualChanging
	|FROM
	|	Catalog.Banks AS Banks
	|WHERE
	|	Banks.Ref = &Ref";
	
	Query.SetParameter("Ref", Form.Object.Ref);
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	
	If QueryResult.IsEmpty() Then
		
		Form.ManualChanging = Undefined;
		
	Else
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		If Selection.ManualChanging >= 2 Then
			Form.ManualChanging = Undefined;
		Else
			Form.ManualChanging = Selection.ManualChanging;
		EndIf;
		
	EndIf;
	
	If Form.ManualChanging = Undefined Then
		RefToClassifier = ReferenceOnClassifier(Form.Object.Code);
		If ValueIsFilled(RefToClassifier) Then
			Query.SetParameter("Ref", RefToClassifier);
			Query.Text =
			"SELECT
			|	BankClassifier.OutOfBusiness
			|FROM
			|	Catalog.BankClassifier AS BankClassifier
			|WHERE
			|	BankClassifier.Ref = &Ref";
			
			Selection = Query.Execute().Select();
			Selection.Next();
			Form.OutOfBusiness = Selection.OutOfBusiness;
		EndIf;
	EndIf;
	
	ProcessManualEditFlag(Form);
	
EndProcedure

// Function to be changed and Banks catalog record
// by transferred parameters if such bank is not
// in the base, it is created if the bank is not on the first level in the hierarchy, the whole chain of parents is created/copied
//
// Parameters:
//
// - Refs - Array with items of the Structure type - Structure keys - names of
//   the catalog attributes, Structure values - attribute data values
// - IgnoreManualChanging - Boolean - do not process banks changed manually
//   
// Returns:
//
// - Array with items of CatalogRef.Banks type
//
Function RefreshCreateBanksWIB(Refs, IgnoreManualChanging)
	
	BanksArray = New Array;
	
	For ind = 0 To Refs.UBound() Do
		ParametersObject = Refs[ind];
		Bank = ParametersObject.Bank;
		
		If ParametersObject.ManualChanging = 1
			AND Not IgnoreManualChanging Then
			BanksArray.Add(Bank);
			Continue;
		EndIf;
		
		If Bank.IsEmpty() Then
			If ParametersObject.ThisState Then
				BankObject = Catalogs.Banks.CreateFolder();
			Else
				BankObject = Catalogs.Banks.CreateItem();
			EndIf;
		Else
			BankObject = Bank.GetObject();
		EndIf;
		
		Attributes = BankObject.Metadata().Attributes;
		For each Attribute In Attributes Do
			BankObject[Attribute.Name] = Undefined;		
		EndDo;
		
		FillPropertyValues(BankObject, ParametersObject);
		
		BeginTransaction();
		Try
			BankObject.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			
			EventName = ?(EventName = "",
				NStr("en = 'Pick from classifier'; ru = 'Подбор из классификатора';pl = 'Wybierz z klasyfikatora';es_ES = 'Elegir desde el clasificador';es_CO = 'Elegir desde el clasificador';tr = 'Sınıflandırıcıdan seç';it = 'Selezione da classificatore';de = 'Wählen Sie vom Klassifikator aus'"), EventName);
			WriteLogEvent(EventName, 
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			
			Break;
		EndTry;
		
		BanksArray.Add(BankObject.Ref);
	EndDo;
	
	Return BanksArray;
	
EndFunction

// The function selects the classifier data to be copied to
// the Banks catalog item if such bank is
// not in the base, it is created if the bank is not on the first level in the hierarchy, the whole chain of parents is created/copied
//
// Parameters:
//
// - BankReferences - Array with items of CatalogRef.BankClassifier type - the list
//   of classifier values to be processed
// - IgnoreManualChanging - Boolean - do not process banks changed manually
//
// Returns:
//
// - Array with items of CatalogRef.Banks type
//
Function BankClassificatorSelection(Val ReferencesBanks, IgnoreManualChanging = False) Export
	
	BanksArray = New Array;
	
	If ReferencesBanks.Count() = 0 Then
		Return BanksArray;
	EndIf;
	
	LinksHierarchy = SupplementArrayWithRefParents(ReferencesBanks);
	
	Query = New Query;
	Query.SetParameter("LinksHierarchy", LinksHierarchy);
	Query.Text =
	"SELECT
	|	BankClassifier.Code AS BIN,
	|	BankClassifier.Description,
	|	BankClassifier.City,
	|	BankClassifier.Address,
	|	BankClassifier.Phones,
	|	BankClassifier.IsFolder,
	|	BankClassifier.Parent.Code,
	|	BankClassifier.Country
	|INTO TU_BankClassifier
	|FROM
	|	Catalog.BankClassifier AS BankClassifier
	|WHERE
	|	BankClassifier.Ref IN(&LinksHierarchy)
	|
	|INDEX BY
	|	BIN
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Bank,
	|	TU_BankClassifier.BIN AS Code,
	|	TU_BankClassifier.IsFolder AS ThisState,
	|	TU_BankClassifier.Description,
	|	TU_BankClassifier.City,
	|	TU_BankClassifier.Address,
	|	TU_BankClassifier.Phones,
	|	0 AS ManualChanging,
	|	ISNULL(TU_BankClassifier.ParentCode, """") AS ParentCode,
	|	TU_BankClassifier.Country
	|INTO BanksWithoutParents
	|FROM
	|	TU_BankClassifier AS TU_BankClassifier
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_BankClassifier.BIN = Banks.Code
	|WHERE
	|	NOT TU_BankClassifier.IsFolder
	|
	|UNION ALL
	|
	|SELECT
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)),
	|	TU_BankClassifier.BIN,
	|	TU_BankClassifier.IsFolder,
	|	TU_BankClassifier.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	0,
	|	ISNULL(TU_BankClassifier.ParentCode, """"),
	|	NULL
	|FROM
	|	TU_BankClassifier AS TU_BankClassifier
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_BankClassifier.BIN = Banks.Code
	|WHERE
	|	TU_BankClassifier.IsFolder
	|
	|INDEX BY
	|	ParentCode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BanksWithoutParents.Bank,
	|	BanksWithoutParents.Code AS Code,
	|	BanksWithoutParents.ThisState AS ThisState,
	|	BanksWithoutParents.Description,
	|	BanksWithoutParents.City,
	|	BanksWithoutParents.Address,
	|	BanksWithoutParents.Phones,
	|	BanksWithoutParents.ManualChanging,
	|	BanksWithoutParents.ParentCode,
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Parent,
	|	BanksWithoutParents.Country
	|FROM
	|	BanksWithoutParents AS BanksWithoutParents
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON BanksWithoutParents.ParentCode = Banks.Parent
	|
	|ORDER BY
	|	ThisState DESC,
	|	Code";
	
	SetPrivilegedMode(True);
	BanksTable = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	Refs = New Array;
	For Each ValueTableRow In BanksTable Do
		
		ObjectParameters = Common.ValueTableRowToStructure(ValueTableRow);
		DeleteNoValidKeysStructure(ObjectParameters);
		Refs.Add(ObjectParameters);
		
	EndDo;
	
	BanksArray = RefreshCreateBanksWIB(Refs, IgnoreManualChanging);
	
	Return BanksArray;
	
EndFunction

// Data recovery from the common
// object and it changes the object state
//
Procedure RestoreItemFromSharedData(Val Form) Export
	
	BeginTransaction();
	
	Try
		
		Refs = New Array;
		Classifier = ReferenceOnClassifier(Form.Object.Code);
		
		If ValueIsFilled(Classifier) Then
			
			Refs.Add(Classifier);
			BankClassificatorSelection(Refs, True);
			
			Form.ManualChanging = False;
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorMessage = NStr("en = 'Recovery from common data'; ru = 'Восстановить из общих данных';pl = 'Odzyskiwanie ze wspólnych danych';es_ES = 'Recuperación desde los datos comunes';es_CO = 'Recuperación desde los datos comunes';tr = 'Genel veriden yenile';it = 'Recupero dai dati comuni';de = 'Wiederherstellung von gemeinsamen Daten'", CommonClientServer.DefaultLanguageCode());
		WriteLogEvent(ErrorMessage, EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
	Form.Read();
	
EndProcedure

// Receiving the references to the Bank Classifier catalog item by BIC text presentation
// 
Function ReferenceOnClassifier(BIC)
	
	If BIC = "" Then
		Return Catalogs.BankClassifier.EmptyRef();
	EndIf;
	
	Query = New Query;
	QueryText =
	"SELECT
	|	BankClassifier.Ref
	|FROM
	|	Catalog.BankClassifier AS BankClassifier
	|WHERE
	|	BankClassifier.Code = &BIC";
	
	Query.SetParameter("BIC", BIC);
	
	Query.Text = QueryText;
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Return Catalogs.BankClassifier.EmptyRef();
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

// Receiving the references to
// the Banks catalog item by BIC or text presentation
//
Function RefOnBank(BIN, ThisState = False)
	
	If BIN = "" Then
		Return Catalogs.Banks.EmptyRef();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.Ref
	|FROM
	|	Catalog.Banks AS Banks
	|WHERE
	|	Banks.Code = &BIN
	|	AND Banks.IsFolder = &IsFolder";
	
	Query.SetParameter("BIN",       BIN);
	Query.SetParameter("IsFolder", ThisState);
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Return Catalogs.Banks.EmptyRef();
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction

Function SupplementArrayWithRefParents(Val Refs)
	
	TableName = Refs[0].Metadata().FullName();
	
	RefArray = New Array;
	For Each Ref In Refs Do
		RefArray.Add(Ref);
	EndDo;
	
	CurrentRefs = Refs;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Table.Parent AS Ref
	|FROM
	|	" + TableName + " AS
	|Table
	|WHERE Table.Ref
	|	In (&Refs) And Table.Parent <> VALUE(" + TableName + ".EmptyRef)";
	
	While True Do
		Query.SetParameter("Refs", CurrentRefs);
		Result = Query.Execute();
		If Result.IsEmpty() Then
			Break;
		EndIf;
		
		CurrentRefs = New Array;
		Selection = Result.Select();
		While Selection.Next() Do
			CurrentRefs.Add(Selection.Ref);
			RefArray.Add(Selection.Ref);
		EndDo;
	EndDo;
	
	Return RefArray;
	
EndFunction

Procedure DeleteNoValidKeysStructure(ParametersStructureCatalog)
	
	For Each KeyAndValue In ParametersStructureCatalog Do
		If KeyAndValue.Value = Null OR KeyAndValue.Key = "IsFolder" Then
			ParametersStructureCatalog.Delete(KeyAndValue.Key);
		EndIf;
	EndDo;
	
EndProcedure

// It copies all banks to all DE
//
// Parameters  
//   BankTable - ValueTable with the banks
//   AreasForUpdating - Array with a list of area codes
//   FileIdentifier - File UUID for the processed banks
//   ProcessorCode  - String, handler code
//
Procedure BanksExtendedDA(Val BankList, Val FileID, Val ProcessorCode) Export
	
	AreasForUpdating  = SuppliedData.AreasRequireProcessing(
		FileID, "Banks");
	
	For Each DataArea In AreasForUpdating Do
		AreaProcessed = False;
		SetPrivilegedMode(True);
		Common.SetSessionSeparation(True, DataArea);
		SetPrivilegedMode(False);
		
		BeginTransaction();
		
		Try
			
			AreaProcessed = RefreshBanksFromClassifier(BankList, DataArea);
			
			If AreaProcessed Then
				SuppliedData.AreaProcessed(FileID, ProcessorCode, DataArea);
				CommitTransaction();
			Else
				RollbackTransaction();
			EndIf;
			
		Except
			RollbackTransaction();
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure ImportBankClassifier() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ImportBankClassifier);
	
	ClassifierImportParameters = New Map;
	ClassifierImportParameters.Insert("Exported", 0);
	ClassifierImportParameters.Insert("Updated", 0);
	ClassifierImportParameters.Insert("MessageText", "");
	ClassifierImportParameters.Insert("ImportCompleted", False);
	
	BankManager.GetWebsiteData(ClassifierImportParameters);
	
	EventName = NStr("en = 'Bank classifier import.'; ru = 'Загрузка классификатора банков.';pl = 'Import klasyfikatora banków.';es_ES = 'Importación del clasificador de banco.';es_CO = 'Importación del clasificador de banco.';tr = 'Banka sınıflandırıcı içe aktarımı.';it = 'Importazione classificatore bancario.';de = 'Bank-Klassifikator-Import.'", CommonClientServer.DefaultLanguageCode());
	
	If ClassifierImportParameters["ImportCompleted"] Then
		WriteLogEvent(EventName, EventLogLevel.Information, , , ClassifierImportParameters["MessageText"]);
	Else
		WriteLogEvent(EventName, EventLogLevel.Error, , , ClassifierImportParameters["MessageText"]);
	EndIf;
	
EndProcedure

#EndRegion