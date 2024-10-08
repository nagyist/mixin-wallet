import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mixin_bot_sdk_dart/mixin_bot_sdk_dart.dart' as sdk;
import 'package:mixswap_sdk_dart/mixswap_sdk_dart.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../../db/dao/extension.dart';
import '../../db/mixin_database.dart';
import '../../service/account_provider.dart';
import '../../service/mix_swap.dart';
import '../../service/profile/pin_session.dart';
import '../../util/constants.dart';
import '../../util/extension/extension.dart';
import '../../util/hook.dart';
import '../../util/logger.dart';
import '../../util/r.dart';
import '../brightness_theme_data.dart';
import '../router/mixin_routes.dart';
import '../widget/asset_selection_list_widget.dart';
import '../widget/buttons.dart';
import '../widget/dialog/pin_verify_dalog.dart';
import '../widget/external_action_confirm.dart';
import '../widget/mixin_appbar.dart';
import '../widget/mixin_bottom_sheet.dart';
import '../widget/round_container.dart';
import '../widget/symbol.dart';
import '../widget/tip_tile.dart';
import '../widget/toast.dart';

class Swap extends HookWidget {
  const Swap({super.key});

  @override
  Widget build(BuildContext context) {
    final swapClient = MixSwap.client;
    final supportedAssets = useMemoizedFuture(() async {
      var supportedIds = supportedAssetIds;
      if (supportedIds == null || supportedIds.isEmpty) {
        supportedIds =
            (await swapClient.getAssets()).data.map((e) => e.uuid).toList();
      } else {
        unawaited(_updateSupportedAssets(swapClient));
      }
      return context.appServices.findOrSyncAssets(supportedIds);
    }).data;

    final source = context.queryParameters['source'];
    AssetResult? sourceAsset;
    if (source != null) {
      sourceAsset = supportedAssets
          ?.where((e) => e.assetId.equalsIgnoreCase(source))
          .firstOrNull;
    } else if (sourceAssetId != null) {
      sourceAsset = supportedAssets
          ?.where((e) => e.assetId.equalsIgnoreCase(sourceAssetId))
          .firstOrNull;
    }
    AssetResult? destAsset;
    if (destAssetId != null) {
      destAsset = supportedAssets
          ?.where((e) => e.assetId.equalsIgnoreCase(destAssetId))
          .firstOrNull;
    }

    return Scaffold(
      backgroundColor: context.colorScheme.background,
      appBar: MixinAppBar(
        leading: const MixinBackButton2(),
        backgroundColor: context.colorScheme.background,
        title: SelectableText(
          context.l10n.swap,
          style: TextStyle(
            color: context.colorScheme.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          enableInteractiveSelection: false,
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: (supportedAssets == null || supportedAssets.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : _Body(
                swapClient: swapClient,
                supportedAssets: supportedAssets,
                initialSource: sourceAsset,
                initialDest: destAsset),
      ),
    );
  }

  Future<void> _updateSupportedAssets(Client swapClient) async {
    final assetIds =
        (await swapClient.getAssets()).data.map((e) => e.uuid).toList();
    await setSupportedAssetIds(assetIds);
  }
}

class _Body extends HookWidget {
  const _Body({
    required this.swapClient,
    required this.supportedAssets,
    this.initialSource,
    this.initialDest,
  });

  final Client swapClient;
  final List<AssetResult> supportedAssets;
  final AssetResult? initialSource;
  final AssetResult? initialDest;

  @override
  Widget build(BuildContext context) {
    assert(supportedAssets.length > 1);
    final sourceAsset = useState(initialSource ?? _getInitialSource());
    final destAsset = useState(initialDest ?? _getInitialDest());
    final routeData = useState<RouteData?>(null);
    final sourceTextController = useTextEditingController();
    final destTextController = useTextEditingController();
    final sourceFocusNode = useFocusNode(debugLabel: 'source input');
    final showLoading = useState(false);
    final slippageKeys = [
      sourceAsset.value,
      destAsset.value,
      sourceTextController.text,
      destTextController.text
    ];
    final slippage =
        useMemoized(() => calcSlippage(routeData.value), slippageKeys);
    final slippageDisplay =
        useMemoized(() => displaySlippage(slippage), slippageKeys);

    Future<void> updateAmount(
      String text,
      FocusNode inputFocusNode,
      TextEditingController effectedController,
    ) async {
      final amount = double.tryParse(text) ?? 0;
      if (amount == 0) {
        effectedController.text = '';
        routeData.value = null;
        return;
      }

      if (inputFocusNode.hasFocus) {
        showLoading.value = true;
        final routeDataResp = (await swapClient.getRoutes(
                sourceAsset.value.assetId,
                destAsset.value.assetId,
                sourceTextController.text))
            .data;
        showLoading.value = false;
        effectedController.text = routeDataResp.bestSourceReceiveAmount;
        routeData.value = routeDataResp;
      }
    }

    final sourceTextStream = useValueNotifierConvertSteam(sourceTextController);
    useEffect(() {
      final listen = sourceTextStream
          .map((event) => event.text)
          .distinct()
          .debounceTime(const Duration(milliseconds: 500))
          .map((String text) =>
              updateAmount(text, sourceFocusNode, destTextController))
          .listen((_) {});

      return listen.cancel;
    });

    return Container(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(topRadius)),
          color: context.colorScheme.background,
        ),
        child: Column(children: [
          const SizedBox(height: 20),
          _AssetItem(
            asset: sourceAsset,
            textController: sourceTextController,
            supportedAssets: supportedAssets,
            readOnly: false,
            focusNode: sourceFocusNode,
            onSelected: () => sourceTextController.text = '',
          ),
          const SizedBox(height: 12),
          Row(children: [
            const SizedBox(width: 16),
            InkResponse(
                radius: 40,
                onTap: () async {
                  final tmp = sourceAsset.value;
                  sourceAsset.value = destAsset.value;
                  destAsset.value = tmp;
                  sourceTextController.text = '';
                  destTextController.text = '';
                  routeData.value = null;
                  await setSourceAssetId(sourceAsset.value.assetId);
                  await setDestAssetId(destAsset.value.assetId);
                },
                child: Center(
                  child: SizedBox.square(
                    dimension: 40,
                    child: SvgPicture.asset(R.resourcesIcSwitchSvg),
                  ),
                )),
            Expanded(
                child: SelectableText.rich(
              '${context.l10n.balance} ${sourceAsset.value.balance} ${sourceAsset.value.symbol}'
                  .highlight(
                TextStyle(
                  color: context.colorScheme.thirdText,
                  fontSize: 12,
                ),
                '${sourceAsset.value.balance} ${sourceAsset.value.symbol}',
                TextStyle(
                    color: context.colorScheme.primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              textAlign: TextAlign.right,
              enableInteractiveSelection: false,
            )),
            const SizedBox(width: 16),
          ]),
          const SizedBox(height: 12),
          _AssetItem(
            asset: destAsset,
            textController: destTextController,
            supportedAssets: supportedAssets,
            readOnly: true,
            showLoading: showLoading.value,
            onSelected: () => sourceTextController.text = '',
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                if (routeData.value != null)
                  TipTile(
                    text: '${context.l10n.slippage} $slippageDisplay',
                    highlight: slippageDisplay,
                    highlightColor: _colorOfSlippage(context, slippage),
                  ),
                TipTile(
                  text: context.l10n.swapDisclaimer,
                  highlightColor: _colorOfSlippage(context, slippage),
                ),
              ],
            ),
          ),
          const Spacer(),
          HookBuilder(
              builder: (context) => _SwapButton(
                    enable: routeData.value != null &&
                        slippage <= supportMaxSlippage,
                    onTap: () async {
                      if (routeData.value == null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(context.l10n.emptyAmount)));
                        return;
                      }

                      if (destAsset.value.getDestination().isEmpty ||
                          sourceAsset.value.getDestination().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content:
                                Text(context.l10n.assetAddressGeneratingTip),
                          ),
                        );
                        return;
                      }

                      if (slippage > supportMaxSlippage) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(context.l10n
                                .slippageOver('$supportMaxSlippage%'))));
                        return;
                      }

                      final traceId = const Uuid().v4();
                      final memo = buildMixSwapMemo(destAsset.value.assetId);

                      if (context.read<AuthProvider>().isLoginByCredential) {
                        // ignore: deprecated_member_use
                        final api = context.appServices.client.transferApi;
                        final pinCode = await showPinVerifyDialog(context);
                        if (pinCode == null) {
                          return;
                        }
                        try {
                          await computeWithLoading(
                            () => api.transfer(sdk.TransferRequest(
                              assetId: sourceAsset.value.assetId,
                              amount: sourceTextController.text,
                              traceId: traceId,
                              opponentId: mixSwapUserId,
                              memo: memo,
                              pin: encryptPin(context, pinCode),
                            )),
                          );
                          context.push(swapDetailPath.toUri({'id': traceId}),
                              queryParameters: {
                                'source': sourceAsset.value.assetId,
                                'dest': destAsset.value.assetId,
                                'amount': sourceTextController.text,
                              });
                        } catch (error, stacktrace) {
                          e('pay error $error $stacktrace');
                          showErrorToast(error.toDisplayString(context));
                          return;
                        }
                      } else {
                        final uri = Uri.https('mixin.one', 'pay', {
                          'amount': sourceTextController.text,
                          'trace': traceId,
                          'asset': sourceAsset.value.assetId,
                          'recipient': mixSwapUserId,
                          'memo': memo,
                        });

                        final ret = await showAndWaitingExternalAction(
                          context: context,
                          uri: uri,
                          action: () => context.appServices
                              .updateSnapshotByTraceId(traceId: traceId),
                          hint: Text(context.l10n.waitingActionDone),
                        );

                        if (ret) {
                          context.push(swapDetailPath.toUri({'id': traceId}),
                              queryParameters: {
                                'source': sourceAsset.value.assetId,
                                'dest': destAsset.value.assetId,
                                'amount': sourceTextController.text,
                              });
                        }
                      }
                    },
                  )),
          const SizedBox(height: 16),
        ]));
  }

  AssetResult _getInitialSource() =>
      supportedAssets
          .where((e) => e.assetId.equalsIgnoreCase(defaultSourceId))
          .firstOrNull ??
      supportedAssets[0];

  AssetResult _getInitialDest() =>
      supportedAssets
          .where((e) => e.assetId.equalsIgnoreCase(defaultDestId))
          .firstOrNull ??
      supportedAssets[1];

  Color _colorOfSlippage(BuildContext context, double slippage) => slippage > 5
      ? lightBrightnessThemeData.red
      : slippage > 1
          ? lightBrightnessThemeData.warning
          : lightBrightnessThemeData.green;
}

class _AssetItem extends HookWidget {
  const _AssetItem({
    required this.asset,
    required this.textController,
    required this.supportedAssets,
    required this.readOnly,
    required this.onSelected,
    this.showLoading = false,
    this.focusNode,
  });

  final ValueNotifier<AssetResult> asset;
  final TextEditingController textController;
  final List<AssetResult> supportedAssets;
  final VoidCallback onSelected;
  final bool readOnly;
  final bool showLoading;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    void showAssetListBottomSheet(ValueNotifier<AssetResult> asset) {
      showMixinBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => AssetSelectionListWidget(
          onTap: (AssetResult? assetResult) async {
            if (assetResult == null) {
              return;
            }
            asset.value = assetResult;
            if (readOnly) {
              await setDestAssetId(assetResult.assetId);
            } else {
              await setSourceAssetId(assetResult.assetId);
            }
            onSelected.call();
            Navigator.pop(context, asset);
          },
          selectedAssetId: asset.value.assetId,
          source: (faitCurrency) => Stream.value(supportedAssets),
          onCancelPressed: () => Navigator.pop(context, null),
        ),
      );
    }

    return RoundContainer(
      height: 64,
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      child: Row(children: [
        InkWell(
            onTap: () => showAssetListBottomSheet(asset),
            child: Row(children: [
              SymbolIconWithBorder(
                symbolUrl: asset.value.iconUrl,
                chainUrl: asset.value.chainIconUrl,
                size: 40,
                chainBorder: const BorderSide(
                  color: Color(0xfff8f8f8),
                  width: 1.5,
                ),
                chainSize: 14,
              ),
              const SizedBox(width: 10),
              Text(
                asset.value.symbol,
                style: TextStyle(
                  color: context.colorScheme.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 4),
              SvgPicture.asset(R.resourcesIcArrowDownSvg),
              const SizedBox(width: 4),
            ])),
        if (!readOnly)
          _SourceAmountArea(
              amountTextField: _AmountTextField(
                focusNode: focusNode,
                controller: textController,
                readOnly: false,
              ),
              asset: asset)
        else
          _DestAmountArea(
              showLoading: showLoading,
              amountTextField: _AmountTextField(
                focusNode: focusNode,
                controller: textController,
                readOnly: true,
              )),
      ]),
    );
  }
}

class _SourceAmountArea extends StatelessWidget {
  const _SourceAmountArea({
    required this.amountTextField,
    required this.asset,
  });

  final ValueNotifier<AssetResult> asset;
  final Widget amountTextField;

  @override
  Widget build(BuildContext context) => Expanded(
          child: Align(
        alignment: Alignment.centerRight,
        child: amountTextField,
      ));
}

class _DestAmountArea extends StatelessWidget {
  const _DestAmountArea({
    required this.showLoading,
    required this.amountTextField,
  });

  final bool showLoading;
  final Widget amountTextField;

  @override
  Widget build(BuildContext context) => Expanded(
      child: Align(
          alignment: Alignment.centerRight,
          child: AnimatedSwitcher(
              duration: Duration.zero,
              child: showLoading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: context.colorScheme.thirdText,
                        strokeWidth: 2,
                      ))
                  : amountTextField)));
}

class _AmountTextField extends StatelessWidget {
  const _AmountTextField({
    required this.controller,
    required this.readOnly,
    this.focusNode,
  });

  final FocusNode? focusNode;
  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => TextField(
        readOnly: readOnly,
        focusNode: focusNode,
        autofocus: !readOnly,
        style: TextStyle(
          color: context.colorScheme.primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        maxLines: 1,
        decoration: InputDecoration(
          hintText: '0.000',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: context.colorScheme.thirdText,
            fontWeight: FontWeight.w400,
          ),
        ),
        controller: controller,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))
        ],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.end,
      );
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({
    required this.onTap,
    required this.enable,
  });

  final VoidCallback onTap;
  final bool enable;

  @override
  Widget build(BuildContext context) => Material(
        borderRadius: BorderRadius.circular(72),
        color: enable ? const Color(0xFF333333) : const Color(0x33333333),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(72),
          child: SizedBox(
            width: 110,
            height: 48,
            child: Center(
              child: Text(
                context.l10n.swap,
                style: TextStyle(
                  fontSize: 16,
                  color: context.colorScheme.background,
                ),
              ),
            ),
          ),
        ),
      );
}
