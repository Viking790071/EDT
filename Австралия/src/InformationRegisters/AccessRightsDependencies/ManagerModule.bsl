#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Updates register data if the developer changed dependencies in the overridable module.
// 
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	SetPrivilegedMode(True);
	
	AccessRightsDependencies = CreateRecordSet();
	
	Table = New ValueTable;
	Table.Columns.Add("SubordinateTable", New TypeDescription("String"));
	Table.Columns.Add("LeadingTable",     New TypeDescription("String"));
	
	SSLSubsystemsIntegration.OnFillAccessRightsDependencies(Table);
	AccessManagementOverridable.OnFillAccessRightsDependencies(Table);
	
	AccessRightsDependencies = CreateRecordSet().Unload();
	For each Row In Table Do
		NewRow = AccessRightsDependencies.Add();
		
		MetadataObject = Metadata.FindByFullName(Row.SubordinateTable);
		If MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка в процедуре OnFillAccessRightsDependencies
				           |общего модуля AccessManagementOverridable.
				           |
				           |Не найдена подчиненная таблица ""%1"".'; 
				           |en = 'An error occurred in the OnFillAccessRightsDependencies procedure
				           |of the AccessManagementOverridable common module.
				           |
				           |Subordinate table ""%1"" is not found.'; 
				           |pl = 'Błąd w procedurze OnFillAccessRightsDependencies
				           |do wspólnego modułu AccessManagementOverridable.
				           |
				           |Nie znaleziono podległej tabeli ""%1"".';
				           |es_ES = 'Error en el procedimiento OnFillAccessRightsDependencies procedure
				           |del módulo común AccessManagementOverridable.
				           |
				           |No se ha encontrado una tabla subordinada ""%1"".';
				           |es_CO = 'Error en el procedimiento OnFillAccessRightsDependencies procedure
				           |del módulo común AccessManagementOverridable.
				           |
				           |No se ha encontrado una tabla subordinada ""%1"".';
				           |tr = 'ErişimYönetimiGeçersiz 
				           |genel modülünün DoldurmaErişimHakkıBağımlılıkları 
				           | %1 prosedüründe bir hata oluştu. Alt tablo "
" bulunamadı.';
				           |it = 'Errore nella procedura OnFillAccessRightsDependencies
				           |del modulo generale AccessManagementOverridable.
				           |
				           |La tabella subordinata ""%1"" non è stata trovata.';
				           |de = 'Fehler in der Vorgehensweise BeimAusfüllenVonAbhängigkeitenZugriffsRecht
				           |des allgemeinen Moduls ZugriffsKontrolleNeudenierbar.
				           |
				           |Die untergeordnete Tabelle ""%1"" wird nicht gefunden.'"),
				Row.SubordinateTable);
		EndIf;
		NewRow.SubordinateTable = Common.MetadataObjectID(
			Row.SubordinateTable);
		
		MetadataObject = Metadata.FindByFullName(Row.LeadingTable);
		If MetadataObject = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка в процедуре OnFillAccessRightsDependencies
				           |общего модуля AccessManagementOverridable.
				           |
				           |Не найдена ведущая таблица ""%1"".'; 
				           |en = 'An error occurred in the OnFillAccessRightsDependencies procedure
				           |of the AccessManagementOverridable common module.
				           |
				           |Leading table ""%1"" is not found.'; 
				           |pl = 'Błąd w procedurze OnFillAccessRightsDependencies
				           |do wspólnego modułu AccessManagementOverridable.
				           |
				           |Nie znaleziono wiodącej tabeli ""%1';
				           |es_ES = 'Error en el procedimiento OnFillAccessRightsDependencies procedure
				           |del módulo común AccessManagementOverridable.
				           |
				           |No se ha encontrado una tabla principal ""%1"".';
				           |es_CO = 'Error en el procedimiento OnFillAccessRightsDependencies procedure
				           |del módulo común AccessManagementOverridable.
				           |
				           |No se ha encontrado una tabla principal ""%1"".';
				           |tr = 'ErişimYönetimiYenidenTanımlanmış 
				           |genel modülünün DoldurmaErişimHakkıBağımlılıklarıDoldurulurken 
				           | %1 prosedüründe bir hata oluştu. Ana tablo 
				           |"" bulunamadı.';
				           |it = 'Errore nella procedura OnFillAccessRightsDependencies
				           |del modulo generale AccessManagementOverridable.
				           |
				           |La tabella primaria ""%1"" non è stata trovata.';
				           |de = 'Fehler in der Vorgehensweise BeimAusfüllenVonAbhängigkeitenZugriffsRecht
				           |des allgemeinen Moduls ZugriffsKontrolleNeudenierbar.
				           |
				           |Die übergeordnete Tabelle ""%1"" wird nicht gefunden.'"),
				Row.LeadingTable);
		EndIf;
		NewRow.LeadingTableType = Common.ObjectManagerByFullName(
			Row.LeadingTable).EmptyRef();
	EndDo;
	
	TemporaryTablesQueriesText =
	"SELECT
	|	NewData.SubordinateTable,
	|	NewData.LeadingTableType
	|INTO NewData
	|FROM
	|	&AccessRightsDependencies AS NewData";
	
	QueryText =
	"SELECT
	|	NewData.SubordinateTable,
	|	NewData.LeadingTableType,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array;
	Fields.Add(New Structure("SubordinateTable"));
	Fields.Add(New Structure("LeadingTableType"));
	
	Query = New Query;
	AccessRightsDependencies.GroupBy("SubordinateTable, LeadingTableType");
	Query.SetParameter("AccessRightsDependencies", AccessRightsDependencies);
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessRightsDependencies", TemporaryTablesQueriesText);
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.AccessRightsDependencies");
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.AccessRightsDependencies);
		Data.Insert("EditStringContent", Query.Execute().Unload());
		
		AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf