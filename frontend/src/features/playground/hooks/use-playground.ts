// Copyright 2026 DataInfra-RedactionEverything Contributors

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { showToast } from '@/components/Toast';
import { t } from '@/i18n';
import { useServiceHealth, type ServicesHealth } from '@/hooks/use-service-health';
import { authFetch, downloadFile } from '@/services/api-client';
import type { VersionHistoryEntry } from '@/types';
import { localizeErrorMessage } from '@/utils/localizeError';
import { safeJson } from '../utils';
import type { BoundingBox, Entity, FileInfo, RedactionResult, Stage } from '../types';
import { usePlaygroundEntities } from './use-playground-entities';
import { usePlaygroundFile } from './use-playground-file';
import { usePlaygroundHistory } from './use-playground-history';
import { usePlaygroundImage } from './use-playground-image';
import { usePlaygroundRecognition } from './use-playground-recognition';

type ServiceKey = keyof ServicesHealth['services'];

const LAST_PLAYGROUND_FILE_KEY = 'playground:last-file-id';
const PLAYGROUND_DRAFT_PREFIX = 'playground:draft:';

interface StoredPlaygroundFile {
  id: string;
  original_filename?: string;
  file_size?: number;
  file_type?: string;
  is_scanned?: boolean;
  page_count?: number;
  pages?: string[];
  content?: string;
  entities?: Entity[];
  bounding_boxes?: BoundingBox[] | Record<string, BoundingBox[]>;
  output_path?: string | null;
  entity_map?: Record<string, string>;
  redacted_count?: number;
  redaction_history?: unknown[];
}

interface PlaygroundDraft {
  version: 1;
  stage: Stage;
  entities: Entity[];
  boundingBoxes: BoundingBox[];
  currentPage: number;
  entityMap: Record<string, string>;
  redactedCount: number;
}

function draftKey(fileId: string) {
  return `${PLAYGROUND_DRAFT_PREFIX}${fileId}`;
}

function readDraft(fileId: string): PlaygroundDraft | null {
  try {
    const raw = sessionStorage.getItem(draftKey(fileId));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<PlaygroundDraft>;
    return parsed.version === 1 ? (parsed as PlaygroundDraft) : null;
  } catch {
    return null;
  }
}

function flattenStoredBoxes(
  raw: StoredPlaygroundFile['bounding_boxes'],
): BoundingBox[] {
  if (Array.isArray(raw)) return raw;
  if (!raw || typeof raw !== 'object') return [];
  return Object.entries(raw).flatMap(([page, boxes]) =>
    Array.isArray(boxes)
      ? boxes.map((box) => ({ ...box, page: Number(box.page || page || 1) }))
      : [],
  );
}

function isServiceBlocked(health: ServicesHealth | null, key: ServiceKey) {
  const service = health?.services[key];
  if (!service) return false;
  if (service.status === 'offline') return true;
  if (service.status !== 'degraded') return false;

  // A degraded service can still be operational (for example PaddleOCR on
  // macOS CPU). Only stop recognition when the health probe explicitly says
  // the service cannot be reached or is not ready.
  return service.detail?.reachable === false || service.detail?.ready === false;
}

function serviceLabel(health: ServicesHealth, key: ServiceKey) {
  const service = health.services[key];
  if (!service) return String(key);
  return `${t(`health.service.${key}`)}：${t(`health.${service.status}`)}`;
}

export function usePlayground() {
  const location = useLocation();
  const routeFileId = useMemo(() => {
    const match = location.pathname.match(/^\/(?:single|playground)\/([^/]+)$/);
    if (!match) return null;
    try {
      return decodeURIComponent(match[1]);
    } catch {
      return match[1];
    }
  }, [location.pathname]);
  const recognition = usePlaygroundRecognition();
  const { health, checking: healthChecking } = useServiceHealth();

  const latestOcrHasTypesRef = useRef(recognition.selectedOcrHasTypes);
  const latestVisualFeatureTypesRef = useRef(recognition.selectedVisualFeatureTypes);
  const latestSelectedTypesRef = recognition.selectedTypesRef;
  latestOcrHasTypesRef.current = recognition.selectedOcrHasTypes;
  latestVisualFeatureTypesRef.current = recognition.selectedVisualFeatureTypes;

  const entityCtx = usePlaygroundEntities();

  const [redactionReport, setRedactionReport] = useState<Record<string, unknown> | null>(null);
  const [reportOpen, setReportOpen] = useState(false);
  const [versionHistory, setVersionHistory] = useState<VersionHistoryEntry[]>([]);
  const [versionHistoryOpen, setVersionHistoryOpen] = useState(false);
  const [redactedCount, setRedactedCount] = useState(0);
  const [entityMap, setEntityMap] = useState<Record<string, string>>({});
  const [redactionVersion, setRedactionVersion] = useState(0);
  const [resetConfirmOpen, setResetConfirmOpen] = useState(false);
  const latestFileIdRef = useRef<string | null>(null);
  const asyncResultEpochRef = useRef(0);
  const redactionAbortRef = useRef<AbortController | null>(null);
  const redactionInFlightRef = useRef(false);
  const restoredFileIdRef = useRef<string | null>(null);

  const getRecognitionBlocker = useCallback(
    (file: { fileType: string; isScanned: boolean; content: string }) => {
      if (!health || healthChecking) return null;

      const requiredServices = new Set<ServiceKey>();
      const isImage = file.fileType === 'image' || file.isScanned;
      if (isImage) {
        if (latestOcrHasTypesRef.current.length > 0) {
          requiredServices.add('paddle_ocr');
          requiredServices.add('has_ner');
        }
        if (latestVisualFeatureTypesRef.current.length > 0) {
          requiredServices.add('visual_features');
        }
      } else if (file.content && latestSelectedTypesRef.current.length > 0) {
        requiredServices.add('has_ner');
      }

      const blocked = [...requiredServices].filter((key) => isServiceBlocked(health, key));
      if (blocked.length === 0) return null;

      return t('playground.recognitionPausedModelServices').replace(
        '{services}',
        blocked.map((key) => serviceLabel(health, key)).join(', '),
      );
    },
    [health, healthChecking, latestSelectedTypesRef],
  );

  const fileCtx = usePlaygroundFile({
    latestOcrHasTypesRef,
    latestVisualFeatureTypesRef,
    latestSelectedTypesRef,
    resetEntityHistory: entityCtx.entityHistory.reset,
    resetImageHistory: () => imageCtx.imageHistory.reset(),
    setEntities: entityCtx.setEntities,
    setBoundingBoxes: (val) => imageCtx.setBoundingBoxes(val),
    getRecognitionBlocker,
  });

  const imageCtx = usePlaygroundImage({
    fileInfo: fileCtx.fileInfo,
    redactionVersion,
    showRedactedPreview: fileCtx.stage === 'result',
  });

  useEffect(() => {
    if (!routeFileId) return;
    if (fileCtx.fileInfo?.file_id === routeFileId) {
      restoredFileIdRef.current = routeFileId;
      return;
    }
    if (restoredFileIdRef.current === routeFileId) return;

    restoredFileIdRef.current = routeFileId;
    const controller = new AbortController();

    const restoreWorkspace = async () => {
      fileCtx.setIsLoading(true);
      fileCtx.setLoadingMessage(t('playground.parsing'));
      fileCtx.setRecognitionIssue(null);
      try {
        const infoRes = await authFetch(`/api/v1/files/${encodeURIComponent(routeFileId)}`, {
          signal: controller.signal,
        });
        if (!infoRes.ok) throw new Error(t('playground.parseFailed'));
        let stored = await safeJson<StoredPlaygroundFile>(infoRes);

        if (typeof stored.content !== 'string') {
          const parseRes = await authFetch(
            `/api/v1/files/${encodeURIComponent(routeFileId)}/parse`,
            { signal: controller.signal },
          );
          if (parseRes.ok) {
            const parsed = await safeJson<Partial<StoredPlaygroundFile>>(parseRes);
            stored = { ...stored, ...parsed };
          }
        }
        if (controller.signal.aborted) return;

        const serverEntities = Array.isArray(stored.entities) ? stored.entities : [];
        const serverBoxes = flattenStoredBoxes(stored.bounding_boxes);
        const draft = readDraft(routeFileId);
        const hasOutput = Boolean(stored.output_path);
        const restoredStage: Stage = hasOutput
          ? draft?.stage === 'preview'
            ? 'preview'
            : 'result'
          : 'preview';
        const restoredFile: FileInfo = {
          file_id: stored.id || routeFileId,
          filename: stored.original_filename || routeFileId,
          file_size: Number(stored.file_size || 0),
          file_type: stored.file_type,
          is_scanned: Boolean(stored.is_scanned),
          page_count: Math.max(1, Number(stored.page_count || 1)),
          pages: Array.isArray(stored.pages) ? stored.pages : undefined,
        };

        fileCtx.setFileInfo(restoredFile);
        fileCtx.setContent(typeof stored.content === 'string' ? stored.content : '');
        fileCtx.setStage(restoredStage);
        entityCtx.setEntities(
          draft?.entities && draft.entities.length > 0 ? draft.entities : serverEntities,
        );
        entityCtx.entityHistory.reset();
        imageCtx.setBoundingBoxes(draft?.boundingBoxes ?? serverBoxes);
        imageCtx.imageHistory.reset();
        imageCtx.setCurrentPage(
          Math.min(
            Math.max(1, Number(draft?.currentPage || 1)),
            Math.max(1, Number(stored.page_count || 1)),
          ),
        );
        setEntityMap(draft?.entityMap ?? stored.entity_map ?? {});
        setRedactedCount(Number(draft?.redactedCount ?? stored.redacted_count ?? 0));
        setRedactionVersion(Array.isArray(stored.redaction_history) ? stored.redaction_history.length : 0);
        sessionStorage.setItem(LAST_PLAYGROUND_FILE_KEY, routeFileId);

        if (hasOutput) {
          void authFetch(`/api/v1/redaction/${encodeURIComponent(routeFileId)}/report`, {
            signal: controller.signal,
          })
            .then((res) => (res.ok ? safeJson<Record<string, unknown>>(res) : null))
            .then((report) => {
              if (!controller.signal.aborted) setRedactionReport(report);
            })
            .catch(() => undefined);
          void authFetch(`/api/v1/redaction/${encodeURIComponent(routeFileId)}/versions`, {
            signal: controller.signal,
          })
            .then((res) =>
              res.ok ? safeJson<{ versions?: VersionHistoryEntry[] }>(res) : null,
            )
            .then((data) => {
              if (!controller.signal.aborted) setVersionHistory(data?.versions || []);
            })
            .catch(() => undefined);
        } else {
          setRedactionReport(null);
          setVersionHistory([]);
        }
      } catch (err) {
        if (controller.signal.aborted) return;
        restoredFileIdRef.current = null;
        const message = localizeErrorMessage(err, 'playground.parseFailed');
        fileCtx.setRecognitionIssue(message);
        showToast(message, 'error');
      } finally {
        if (!controller.signal.aborted) {
          fileCtx.setIsLoading(false);
          fileCtx.setLoadingMessage('');
        }
      }
    };

    void restoreWorkspace();
    return () => controller.abort();
    // Route id is the restore boundary. State setters are stable React dispatchers.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [routeFileId]);

  useEffect(() => {
    const fileId = fileCtx.fileInfo?.file_id;
    if (!fileId || fileCtx.isLoading) return;
    const timer = window.setTimeout(() => {
      const draft: PlaygroundDraft = {
        version: 1,
        stage: fileCtx.stage,
        entities: entityCtx.entities,
        boundingBoxes: imageCtx.boundingBoxes,
        currentPage: imageCtx.currentPage,
        entityMap,
        redactedCount,
      };
      sessionStorage.setItem(draftKey(fileId), JSON.stringify(draft));
      sessionStorage.setItem(LAST_PLAYGROUND_FILE_KEY, fileId);
    }, 150);
    return () => window.clearTimeout(timer);
  }, [
    entityCtx.entities,
    entityMap,
    fileCtx.fileInfo?.file_id,
    fileCtx.isLoading,
    fileCtx.stage,
    imageCtx.boundingBoxes,
    imageCtx.currentPage,
    redactedCount,
  ]);

  const { setTypeTab } = recognition;
  useEffect(() => {
    setTypeTab(fileCtx.isImageMode ? 'vision' : 'text');
  }, [fileCtx.isImageMode, setTypeTab]);

  useEffect(() => {
    latestFileIdRef.current = fileCtx.fileInfo?.file_id ?? null;
    asyncResultEpochRef.current += 1;
  }, [fileCtx.fileInfo?.file_id]);

  useEffect(
    () => () => {
      redactionAbortRef.current?.abort();
    },
    [],
  );

  const allSelectedVisionTypes = useMemo(
    () => [
      ...recognition.selectedOcrHasTypes,
      ...recognition.selectedVisualFeatureTypes,
    ],
    [
      recognition.selectedOcrHasTypes,
      recognition.selectedVisualFeatureTypes,
    ],
  );

  const historyCtx = usePlaygroundHistory({
    isImageMode: fileCtx.isImageMode,
    entities: entityCtx.entities,
    setEntities: entityCtx.setEntities,
    boundingBoxes: imageCtx.boundingBoxes,
    visibleBoxes: imageCtx.visibleBoxes,
    setBoundingBoxes: imageCtx.setBoundingBoxes,
    entityHistory: entityCtx.entityHistory,
    imageHistory: imageCtx.imageHistory,
    allSelectedVisionTypes,
  });

  const canApplyAsyncResult = useCallback((fileId: string, epoch: number) => {
    return latestFileIdRef.current === fileId && asyncResultEpochRef.current === epoch;
  }, []);

  // Destructured so handleRerunNer can depend on the exact fields it uses
  // instead of the whole (per-render) ctx objects.
  const { setRecognitionIssue } = fileCtx;
  const { handleRerunNerImage } = imageCtx;
  const { handleRerunNerText } = entityCtx;

  const handleRerunNer = useCallback(async () => {
    if (!fileCtx.fileInfo) return;
    const blocker = getRecognitionBlocker({
      fileType: fileCtx.fileInfo.file_type || '',
      isScanned: Boolean(fileCtx.fileInfo.is_scanned),
      content: fileCtx.content,
    });
    if (blocker) {
      setRecognitionIssue(blocker);
      showToast(blocker, 'info');
      return;
    }
    setRecognitionIssue(null);
    if (fileCtx.isImageMode) {
      await handleRerunNerImage(
        fileCtx.fileInfo.file_id,
        recognition.selectedOcrHasTypes,
        recognition.selectedVisualFeatureTypes,
        fileCtx.setIsLoading,
        fileCtx.setLoadingMessage,
      );
    } else {
      await handleRerunNerText(
        fileCtx.fileInfo.file_id,
        recognition.selectedTypesRef.current,
        fileCtx.setIsLoading,
        fileCtx.setLoadingMessage,
      );
    }
  }, [
    fileCtx.content,
    fileCtx.fileInfo,
    fileCtx.isImageMode,
    fileCtx.setIsLoading,
    fileCtx.setLoadingMessage,
    getRecognitionBlocker,
    handleRerunNerImage,
    handleRerunNerText,
    recognition.selectedOcrHasTypes,
    recognition.selectedTypesRef,
    recognition.selectedVisualFeatureTypes,
    setRecognitionIssue,
  ]);

  const presetSeqRef = useRef(recognition.presetApplySeq);
  useEffect(() => {
    if (recognition.presetApplySeq === presetSeqRef.current) return;
    presetSeqRef.current = recognition.presetApplySeq;
    if (!fileCtx.fileInfo || fileCtx.isLoading) return;
    if (fileCtx.stage !== 'preview') return;
    void handleRerunNer();
  }, [
    recognition.presetApplySeq,
    fileCtx.fileInfo,
    fileCtx.isLoading,
    fileCtx.stage,
    handleRerunNer,
  ]);

  const handleRedact = useCallback(async () => {
    if (!fileCtx.fileInfo) return;
    if (redactionInFlightRef.current) return;

    redactionAbortRef.current?.abort();
    const controller = new AbortController();
    redactionAbortRef.current = controller;
    redactionInFlightRef.current = true;
    const { signal } = controller;

    const fileId = fileCtx.fileInfo.file_id;
    fileCtx.setIsLoading(true);
    fileCtx.setLoadingMessage(t('playground.redacting'));

    try {
      const selectedEntities = entityCtx.entities.filter((e) => e.selected !== false);
      const selectedBoxes = imageCtx.boundingBoxes.filter((b) => b.selected !== false);
      const requestedRedactionItemCount = fileCtx.isImageMode
        ? selectedBoxes.length
        : selectedEntities.length;

      const res = await authFetch('/api/v1/redaction/execute', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          file_id: fileId,
          entities: entityCtx.entities,
          bounding_boxes: imageCtx.boundingBoxes,
          config: {
            replacement_mode: recognition.replacementMode,
            entity_types: [],
            custom_replacements: {},
            watermark_text: recognition.watermarkText.trim() || undefined,
          },
        }),
        signal,
      });
      if (signal.aborted) return;

      if (!res.ok) throw new Error(t('playground.redactFailed'));
      const result = await safeJson<RedactionResult>(res);
      if (signal.aborted) return;
      const completedCount = requestedRedactionItemCount;
      setEntityMap(result.entity_map || {});
      setRedactedCount(completedCount);
      setRedactionVersion((version) => version + 1);
      fileCtx.setStage('result');

      latestFileIdRef.current = fileId;
      const asyncResultEpoch = asyncResultEpochRef.current + 1;
      asyncResultEpochRef.current = asyncResultEpoch;

      const loadAsyncResult = async <T>(url: string): Promise<T> => {
        const response = await authFetch(url, { signal });
        if (signal.aborted) {
          throw new DOMException('Aborted', 'AbortError');
        }
        if (!response.ok) {
          throw new Error(`Failed to load ${url}`);
        }
        return safeJson<T>(response);
      };

      loadAsyncResult<Record<string, unknown>>(`/api/v1/redaction/${fileId}/report`)
        .then((data) => {
          if (canApplyAsyncResult(fileId, asyncResultEpoch)) {
            setRedactionReport(data);
          }
        })
        .catch(() => {
          if (canApplyAsyncResult(fileId, asyncResultEpoch)) {
            setRedactionReport(null);
          }
        });

      loadAsyncResult<{ versions?: VersionHistoryEntry[] }>(`/api/v1/redaction/${fileId}/versions`)
        .then((data) => {
          if (canApplyAsyncResult(fileId, asyncResultEpoch)) {
            setVersionHistory(data.versions || []);
          }
        })
        .catch(() => {
          if (canApplyAsyncResult(fileId, asyncResultEpoch)) {
            setVersionHistory([]);
          }
        });

      showToast(
        t('playground.toast.redactDone').replace('{count}', String(completedCount)),
        'success',
      );
    } catch (err) {
      if (signal.aborted) return;
      showToast(localizeErrorMessage(err, 'playground.redactFailed'), 'error');
    } finally {
      if (redactionAbortRef.current === controller) {
        redactionAbortRef.current = null;
      }
      redactionInFlightRef.current = false;
      if (!signal.aborted) {
        fileCtx.setIsLoading(false);
        fileCtx.setLoadingMessage('');
      }
    }
  }, [
    canApplyAsyncResult,
    entityCtx.entities,
    fileCtx,
    imageCtx.boundingBoxes,
    recognition.replacementMode,
    recognition.watermarkText,
  ]);

  const cancelProcessing = useCallback(() => {
    asyncResultEpochRef.current += 1;
    redactionAbortRef.current?.abort();
    redactionAbortRef.current = null;
    redactionInFlightRef.current = false;
    fileCtx.cancelProcessing(false);
    entityCtx.cancelRerunNerText();
    imageCtx.cancelRerunNerImage();
    fileCtx.setIsLoading(false);
    fileCtx.setLoadingMessage('');
    showToast(t('playground.cancelled'), 'info');
  }, [entityCtx, fileCtx, imageCtx]);

  const hasResetRisk = useMemo(
    () =>
      fileCtx.stage !== 'upload' ||
      fileCtx.fileInfo !== null ||
      fileCtx.content.length > 0 ||
      entityCtx.entities.length > 0 ||
      imageCtx.boundingBoxes.length > 0 ||
      redactedCount > 0 ||
      Object.keys(entityMap).length > 0 ||
      redactionReport !== null ||
      versionHistory.length > 0,
    [
      entityCtx.entities.length,
      entityMap,
      fileCtx.content.length,
      fileCtx.fileInfo,
      fileCtx.stage,
      imageCtx.boundingBoxes.length,
      redactedCount,
      redactionReport,
      versionHistory.length,
    ],
  );

  const performReset = useCallback(() => {
    const previousFileId = fileCtx.fileInfo?.file_id;
    asyncResultEpochRef.current += 1;
    latestFileIdRef.current = null;
    restoredFileIdRef.current = null;
    redactionAbortRef.current?.abort();
    redactionAbortRef.current = null;
    redactionInFlightRef.current = false;
    setResetConfirmOpen(false);
    fileCtx.setStage('upload');
    fileCtx.setFileInfo(null);
    fileCtx.setContent('');
    entityCtx.setEntities([]);
    setRedactedCount(0);
    setEntityMap({});
    setRedactionVersion(0);
    setRedactionReport(null);
    setReportOpen(false);
    entityCtx.entityHistory.reset();
    imageCtx.setBoundingBoxes([]);
    imageCtx.imageHistory.reset();
    setVersionHistory([]);
    setVersionHistoryOpen(false);
    if (previousFileId) sessionStorage.removeItem(draftKey(previousFileId));
    sessionStorage.removeItem(LAST_PLAYGROUND_FILE_KEY);
  }, [entityCtx, fileCtx, imageCtx]);

  const handleReset = useCallback(() => {
    if (hasResetRisk) {
      setResetConfirmOpen(true);
      return;
    }
    performReset();
  }, [hasResetRisk, performReset]);

  const confirmReset = useCallback(() => {
    performReset();
  }, [performReset]);

  const cancelReset = useCallback(() => {
    setResetConfirmOpen(false);
  }, []);

  const handleDownload = useCallback(() => {
    if (!fileCtx.fileInfo) return;
    // Returns the promise so callers can show a busy state while fetching.
    return downloadFile(
      `/api/v1/files/${fileCtx.fileInfo.file_id}/download?redacted=true`,
      `redacted_${fileCtx.fileInfo.filename}`,
    ).catch((err) => {
      showToast(localizeErrorMessage(err, 'common.downloadFailed'), 'error');
    });
  }, [fileCtx.fileInfo]);

  const openPopout = useCallback(() => {
    imageCtx.openPopout(recognition.visionTypes);
  }, [imageCtx, recognition.visionTypes]);

  return {
    stage: fileCtx.stage,
    setStage: fileCtx.setStage,
    fileInfo: fileCtx.fileInfo,
    content: fileCtx.content,
    isImageMode: fileCtx.isImageMode,
    entities: entityCtx.entities,
    setEntities: entityCtx.setEntities,
    applyEntities: entityCtx.applyEntities,
    boundingBoxes: imageCtx.boundingBoxes,
    setBoundingBoxes: imageCtx.setBoundingBoxes,
    visibleBoxes: imageCtx.visibleBoxes,
    isLoading: fileCtx.isLoading,
    loadingMessage: fileCtx.loadingMessage,
    uploadIssue: fileCtx.uploadIssue,
    recognitionIssue: fileCtx.recognitionIssue,
    entityMap,
    redactedCount,
    redactionReport,
    reportOpen,
    setReportOpen,
    versionHistory,
    versionHistoryOpen,
    setVersionHistoryOpen,
    selectedCount: historyCtx.selectedCount,
    canUndo: historyCtx.canUndo,
    canRedo: historyCtx.canRedo,
    handleUndo: historyCtx.handleUndo,
    handleRedo: historyCtx.handleRedo,
    entityHistory: entityCtx.entityHistory,
    imageHistory: imageCtx.imageHistory,
    selectAll: historyCtx.selectAll,
    deselectAll: historyCtx.deselectAll,
    toggleBox: imageCtx.toggleBox,
    removeEntity: entityCtx.removeEntity,
    handleRerunNer,
    handleRedact,
    cancelProcessing,
    handleReset,
    resetConfirmOpen,
    confirmReset,
    cancelReset,
    handleDownload,
    dropzone: fileCtx.dropzone,
    imageUrl: imageCtx.imageUrl,
    redactedImageUrl: imageCtx.redactedImageUrl,
    redactedImageError: imageCtx.redactedImageError,
    currentPage: imageCtx.currentPage,
    setCurrentPage: imageCtx.setCurrentPage,
    totalPages: imageCtx.totalPages,
    mergeVisibleBoxes: imageCtx.mergeVisibleBoxes,
    openPopout,
    recognition,
  };
}
