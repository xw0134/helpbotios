package com.example.HelpBot.thread;

import com.example.HelpBot.log.HBlogger;

import java.util.Locale;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.RejectedExecutionHandler;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import androidx.annotation.NonNull;

/**
 * HelpBot SDK 线程池管理器。
 * 负责 SDK 内部异步任务的调度与执行，包含自定义线程工厂和拒绝策略。
 */
public class HelpBotThreadPool {
    private static final String TAG = "HelpBotThreadPool";

    // 线程池配置参数
    private static final int CORE_POOL_SIZE = 2; // 核心线程数
    private static final int MAXIMUM_POOL_SIZE = 4; // 最大线程数
    private static final long KEEP_ALIVE_TIME = 60L; // 空闲线程存活时间(秒)
    private static final int QUEUE_CAPACITY = 128; // 任务队列容量

    private static volatile HelpBotThreadPool instance;
    private final ThreadPoolExecutor executor;
    private final AtomicBoolean isShutdown = new AtomicBoolean(false);

    /**
     * 获取线程池单例实例。
     */
    public static HelpBotThreadPool getInstance() {
        if (instance == null) {
            synchronized (HelpBotThreadPool.class) {
                if (instance == null) {
                    instance = new HelpBotThreadPool();
                }
            }
        }
        return instance;
    }

    /**
     * 私有构造函数，初始化线程池。
     */
    private HelpBotThreadPool() {
        // 创建任务队列
        final BlockingQueue<Runnable> workQueue = new LinkedBlockingQueue<>(QUEUE_CAPACITY);

        // 创建线程工厂
        final ThreadFactory threadFactory = new HelpBotThreadFactory();

        // 创建拒绝策略
        final RejectedExecutionHandler rejectedHandler = new HelpBotRejectedHandler();

        // 创建线程池
        this.executor = new ThreadPoolExecutor(
                CORE_POOL_SIZE,
                MAXIMUM_POOL_SIZE,
                KEEP_ALIVE_TIME,
                TimeUnit.SECONDS,
                workQueue,
                threadFactory,
                rejectedHandler);

        // 允许核心线程超时（设置为 false 保持核心线程存活）
        this.executor.allowCoreThreadTimeOut(false);

        HBlogger.d(TAG, "线程池初始化成功 [核心:" + CORE_POOL_SIZE +
                ", 最大:" + MAXIMUM_POOL_SIZE + ", 队列:" + QUEUE_CAPACITY + "]");
    }

    /**
     * 提交任务到线程池。
     *
     * @param task 要执行的任务
     * @return 返回是否提交成功
     */
    public AtomicBoolean submit(final Runnable task) {
        final AtomicBoolean result = new AtomicBoolean(false);

        if (task == null) {
            HBlogger.e(TAG, "提交的任务为空 (null)");
            return result;
        }

        if (isShutdown.get()) {
            HBlogger.e(TAG, "线程池已关闭，无法提交新任务");
            return result;
        }

        try {
            // 包装任务，添加异常处理
            final Runnable wrappedTask = new SafeRunnable(task);
            executor.execute(wrappedTask);
            result.set(true);
        } catch (final Exception e) {
            HBlogger.e(TAG, "任务提交失败", e);
        }

        return result;
    }

    /**
     * 获取线程池状态信息。
     */
    public String getPoolStatus() {
        return String.format(Locale.ROOT, "线程池状态 [核心:%d, 最大:%d, 活跃:%d, 队列:%d/%d, 完成:%d]",
                executor.getCorePoolSize(),
                executor.getMaximumPoolSize(),
                executor.getActiveCount(),
                executor.getQueue().size(),
                QUEUE_CAPACITY,
                executor.getCompletedTaskCount());
    }

    /**
     * 关闭线程池。
     * 注意：关闭后无法再提交新任务。
     * 
     */
    public void shutdown() {
        if (isShutdown.compareAndSet(false, true)) {
            HBlogger.d(TAG, "开始关闭线程池...");
            executor.shutdown();
            try {
                // 等待 60 秒让正在执行的任务完成
                if (!executor.awaitTermination(60, TimeUnit.SECONDS)) {
                    HBlogger.w(TAG, "线程池未能在 60 秒内正常关闭，强制停止");
                    executor.shutdownNow();
                } else {
                    HBlogger.d(TAG, "线程池已优雅关闭");
                }
            } catch (final InterruptedException e) {
                HBlogger.e(TAG, "线程池关闭过程中被中断", e);
                executor.shutdownNow();
                Thread.currentThread().interrupt();
            } finally {
                // 清空单例实例，允许重新初始化（支持 SDK destroy 后 reinstall）
                synchronized (HelpBotThreadPool.class) {
                    instance = null;
                }
                HBlogger.d(TAG, "线程池单例已重置，支持重新初始化");
            }
        }
    }

    /**
     * 立即关闭线程池 (不等待任务完成)。
     * - 立即停止所有任务，清空单例实例
     */
    public void shutdownNow() {
        if (isShutdown.compareAndSet(false, true)) {
            HBlogger.w(TAG, "强制立即关闭线程池");
            try {
                executor.shutdownNow();
            } finally {
                // 清空单例实例
                synchronized (HelpBotThreadPool.class) {
                    instance = null;
                }
                HBlogger.d(TAG, "线程池单例已重置，支持重新初始化");
            }
        }
    }

    /**
     * 自定义线程工厂，用于线程命名和异常处理。
     */
    private static class HelpBotThreadFactory implements ThreadFactory {
        private final AtomicInteger threadNumber = new AtomicInteger(1);
        private final String namePrefix = "HelpBot-Worker-";

        @Override
        public Thread newThread(@NonNull final Runnable r) {
            final Thread thread = new Thread(r, namePrefix + threadNumber.getAndIncrement());

            // 设置为非守护线程
            thread.setDaemon(false);

            // 设置优先级为普通
            thread.setPriority(Thread.NORM_PRIORITY);

            // 设置未捕获异常处理器
            thread.setUncaughtExceptionHandler((t, e) -> {
                HBlogger.e(TAG, "线程 " + t.getName() + " 发生未捕获异常", e);
            });

            return thread;
        }
    }

    /**
     * 自定义拒绝策略。
     * 当线程池和队列都满时的处理逻辑。
     */
    private static class HelpBotRejectedHandler implements RejectedExecutionHandler {
        @Override
        public void rejectedExecution(final Runnable r, final ThreadPoolExecutor executor) {
            HBlogger.e(TAG, "任务被拒绝 [活跃线程:" + executor.getActiveCount() +
                    ", 队列大小:" + executor.getQueue().size() + "]");
        }
    }

    /**
     * 安全的 Runnable 包装器。
     * 捕获任务执行中的所有异常，防止线程池线程因未捕获异常而退出。
     */
    private static class SafeRunnable implements Runnable {
        private final Runnable delegate;

        SafeRunnable(final Runnable delegate) {
            this.delegate = delegate;
        }

        @Override
        public void run() {
            try {
                delegate.run();
            } catch (final Throwable t) {
                // 捕获所有异常和错误，防止线程池线程退出
                HBlogger.e(TAG, "线程池任务执行发生异常", t);
            }
        }
    }
}
