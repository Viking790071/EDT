///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Owner.DeletionMark Then
		Return;
	EndIf;

	If NOT Interactions.UserIsResponsibleForMaintainingFolders(Owner) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Данная операция доступна только ответственному за ведение папок для данной учетной записи'; en = 'This operation is available only to users responsible for the account''s folders.'; pl = 'Ta operacja jest dostępna tylko dla użytkowników odpowiedzialnych za prowadzenie folderów konta.';es_ES = 'Esta operación sólo está disponible para los usuarios responsables de las carpetas de cuenta.';es_CO = 'Esta operación sólo está disponible para los usuarios responsables de las carpetas de cuenta.';tr = 'Bu işlem sadece hesabın klasörlerinden sorumlu olan kullanıcılar tarafından yapılabilir.';it = 'Questa operazione è disponibile solamente per gli utenti responsabili delle cartelle dell''account.';de = 'Diese Operation ist nur für Benutzer verantwortlich für die Kontenordner verfügbar.'"),
			Ref,,,Cancel);
	ElsIf PredefinedFolder AND DeletionMark AND (NOT Owner.DeletionMark) Then
		CommonClientServer.MessageToUser(
		NStr("ru = 'Нельзя установить пометку удаления для предопределенной папки'; en = 'Cannot set a deletion mark to a predefined folder.'; pl = 'Nie można ustawić zaznaczenie do usunięcia dla predefiniowanego foldera.';es_ES = 'No se puede establecer una marca de borrado en una carpeta predefinida.';es_CO = 'No se puede establecer una marca de borrado en una carpeta predefinida.';tr = 'Ön tanımlı klasör için silme işareti ayarlanamadı.';it = 'Impossibile impostare un contrassegno di eliminazione per una cartella predefinita.';de = 'Kann keine Löschmarkierung für einen vordefinierten Ordner aktivieren.'"),
		Ref,,,Cancel);
	ElsIf PredefinedFolder AND (Not Parent.IsEmpty()) Then
	CommonClientServer.MessageToUser(
		NStr("ru = 'Нельзя переместить предопределенную папку в другую папку'; en = 'Cannot move a predefined folder to another folder.'; pl = 'Nie można przenieść predefiniowanego folderu do innego folderu.';es_ES = 'No se puede mover la carpeta predefinida a otra carpeta.';es_CO = 'No se puede mover la carpeta predefinida a otra carpeta.';tr = 'Öntanımlı klasör başka bir klasöre taşınamaz.';it = 'Impossibile spostare una cartella predefinita in un''altra cartella.';de = 'Kann keinen vordefinierten Ordner in einen anderen Ordner verschieben.'"),
		Ref,,,Cancel);
	EndIf;
	
	AdditionalProperties.Insert("Parent",Common.ObjectAttributeValue(Ref,"Parent"));
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	PredefinedFolder = False;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("Parent") AND Parent <> AdditionalProperties.Parent Then
		If NOT AdditionalProperties.Property("ParentChangeProcessed") Then
			Interactions.SetFolderParent(Ref,Parent,True)
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu na kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektaufruf auf dem Client.'");
#EndIf