import re

with open('louce/lib/components/action_card.dart', 'r') as f:
    content = f.read()

# Replace the start of the Row
content = content.replace(
'''          // ── Main Execution Grid ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left Column: Inputs & Logs ──
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [''',
'''          // ── Main Execution Grid ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;
              final leftColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: ['''
)

# Replace the middle separator
content = content.replace(
'''                  ],
                ),
              ),

              const SizedBox(width: 32),

              // ── Right Column: Output ──
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [''',
'''                  ],
              );

              final rightColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: ['''
)

# Replace the end
content = content.replace(
'''                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}''',
'''                  ],
              );

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: leftColumn),
                    const SizedBox(width: 32),
                    Expanded(flex: 1, child: rightColumn),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftColumn,
                    const SizedBox(height: 32),
                    rightColumn,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}'''
)

# Add the DOWNLOAD button
content = content.replace(
'''                                        GreenButton(
                                          label: 'HTML',
                                          onPressed: _formatBusy
                                              ? null
                                              : () => _switchFormat(ReportFormat.html),
                                          borderColor: _formatColor(ReportFormat.html),
                                          textColor: _formatColor(ReportFormat.html),
                                        ),''',
'''                                        GreenButton(
                                          label: 'HTML',
                                          onPressed: _formatBusy
                                              ? null
                                              : () => _switchFormat(ReportFormat.html),
                                          borderColor: _formatColor(ReportFormat.html),
                                          textColor: _formatColor(ReportFormat.html),
                                        ),
                                        const SizedBox(width: 8),
                                        GreenButton(
                                          label: 'DOWNLOAD',
                                          onPressed: () {
                                            if (session.report != null) {
                                               ScaffoldMessenger.of(context).showSnackBar(
                                                 SnackBar(
                                                   backgroundColor: MidnightHacker.background,
                                                   content: Text('File accessible at: ${ref.read(navigationProvider).outputSaveLocation}', style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.primary)),
                                                   shape: Border.all(color: MidnightHacker.primary),
                                                 )
                                               );
                                            }
                                          },
                                          icon: Icons.download_outlined,
                                          borderColor: MidnightHacker.primary,
                                          textColor: MidnightHacker.primary,
                                        ),'''
)

with open('louce/lib/components/action_card.dart', 'w') as f:
    f.write(content)
